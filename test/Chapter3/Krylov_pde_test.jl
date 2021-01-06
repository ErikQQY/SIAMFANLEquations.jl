"""
gmres_test_pde(n)

PDE test from FR16. Test of kl_gmres with all kinds of preconditioning.
"""
function gmres_test_pde(n; orth = "cgs2", write = false, eta = 9.8 * 1.e-4)
    pdata = pdegminit(n)
    fdata = pdata.fdata
    RHS = pdata.RHS
    ue = pdata.ue
    b = Pfish2d(RHS, fdata)
    u0 = zeros(n * n)
    V = zeros(n * n, 20)
    # Solve with left preconditioning hard-wired in
    goutp = kl_gmres(u0, b, pdelpatv, V, eta; pdata = pdata, orth = orth)
    pcres = goutp.reshist
    pcres /= pcres[1]
    sollhw = goutp.sol
    # Solve with right preconditioning hard-wired in
    goutrp = kl_gmres(u0, RHS, pderatv, V, eta; pdata = pdata, orth = orth)
    pcresr = goutrp.reshist
    pcresr /= pcresr[1]
    solrhw = pdeptv(goutp.sol, pdata)
    # Put left preconditioning in the argument list.
    goutpl2 = kl_gmres(u0, RHS, pdeatv, V, eta, pdeptv;
            pdata = pdata, orth = orth, side = "left")
    pcresl2 = goutpl2.reshist
    pcresl2 /= pcresl2[1]
    soll = goutpl2.sol
    # Put right preconditioning in the argument list.
    goutp2 = kl_gmres( u0, RHS, pdeatv, V, eta, pdeptv;
        pdata = pdata, orth = orth, side = "right")
    pcres2 = goutp2.reshist
    pcres2 /= pcres2[1]
    solr = goutp2.sol
    soldel = norm(solrhw - solr, Inf)
    solrdel = norm(sollhw - soll, Inf)
    solerr = norm(soll - ue, Inf)
    solerr2 = norm(solr - ue, Inf)
    pass =( (soldel == 0) && (solrdel == 0) && (solerr < 1.e-2) 
          && (solerr2 < 1.e-2) && (length(pcresr) == 12 ) && 
          (length(pcres)==9))
    pass || println("Linear pde test for GMRES fails.")
    if write
        println(soldel, "  ", solrdel, "  ", solerr, "   ", solerr2)
    end
    return pass
end

function pdelpatv(u, pdata)
    L = pdata.L
    fdata = pdata.fdata
    au = L * u
    pau = Pfish2d(au, fdata)
    return pau
end

function pderatv(u, pdata)
    L = pdata.L
    fdata = pdata.fdata
    pau = Pfish2d(u, fdata)
    au = L * pau
    return au
end

function pdeptv(u, pdata)
    fdata = pdata.fdata
    ptv = Pfish2d(u, fdata)
end

function pdeatv(u, pdata)
    xc = pdata.xc
    L = pdata.L
    mul!(xc, L, u)
    return xc
end


"""
pdegminit(n)

collects the precomputed data for the linear elliptic pde example. 
This is the example on page 54-55 of FR16.

This
includes

- the sparse matrix representation of the operators,
- the right side of the equation,
- the exact solution,
- the data that the fft-based fast Poisson solver (fish2d) needs
"""
function pdegminit(n)
    # Make the grids
    n2 = n * n
    h = 1.0 / (n + 1.0)
    x = collect(h:h:1.0-h)
    o = ones(n)
    Y = o * x'
    y20 = 20.0 * reshape(Y, (n2,))
    DiagY = Diagonal(y20)
    # collect the operators
    D2 = Lap2d(n)
    DX = Dx2d(n)
    DY = Dy2d(n)
    L = D2 + I
    L .+= DX
    LY = copy(DY)
    mul!(LY, DiagY, DY)
    L .+= LY
    # Exact solution and its derivatives
    uexact = solexact(x)
    dxe = dxexact(x)
    dye = dyexact(x)
    d2e = l2dexact(x)
    dxv = reshape(dxe, (n2,))
    dyv = reshape(dye, (n2,))
    d2v = reshape(d2e, (n2,))
    uv = reshape(uexact, (n2,))
    # Preallocate a copy of the unknown for the function
    # and preconditioner evaluation.
    xc = copy(uv)
    fdata = fishinit(n)
    # The right side of the equation
    RHS = d2v + dxv + y20 .* dyv + uv
    # Pack it and ship it.
    pdedata = (L, RHS = RHS, ue = uv, xc = xc, fdata = fdata)
end