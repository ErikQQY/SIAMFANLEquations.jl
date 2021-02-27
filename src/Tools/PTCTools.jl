"""
PTCUpdate(FPS::AbstractArray, FS, x, ItRules, step, residm, dt)

Updates the PTC iteration. This is a much simpler algorithm that Newton.
We update the Jacobian every iteration and there is no line search
to manage. 

Do not mess with this function!
In particular do not touch the line that calls PrepareJac!.
        FPF = PrepareJac!(FPS, FS, x, ItRules,dt)
PrePareJac! builds F'(u) + (1/dt)I, factors it, and sends ptcsol that
factorization.

FPF is not the same as FPS (the storage you allocate for the Jacobian)
for a reason. FPF and FPS do not have the same type, even though they
share storage. So, FPS=PrepareJac!(FPS, FS, ...) will break things.

"""
function PTCUpdate(FPS::AbstractArray, FS, x, ItRules, step, residm, dt)
    T = eltype(FPS)
    F! = ItRules.f
    pdata = ItRules.pdata
    #
    FPF = PrepareJac!(FPS, FS, x, ItRules, dt)
    #
    #    step .= -(FPF \ FS)
    T == Float64 ? (step .= -(FPF \ FS)) : (step .= -(FPF \ T.(FS)))
    #
    # update solution/function value
    #
    x .= x + step
    EvalF!(F!, FS, x, pdata)
    resnorm = norm(FS)
    #
    # Update dt
    #
    dt *= (residm / resnorm)
    return (x, dt, FS, resnorm)
end

"""
PTCUpdate(df::Real, fval, x, ItRules, step, residm, dt)

PTC for scalar equations. 
"""

function PTCUpdate(df::Real, fval, x, ItRules, step, resnorm, dt)
    f = ItRules.f
    dx = ItRules.dx
    fp = ItRules.fp
    pdata = ItRules.pdata
    df = fpeval_newton(x, f, fval, fp, dx, pdata)
    idt = 1.0 / dt
    step = -fval / (idt + df)
    x = x + step
    #    fval = f(x)
    fval = EvalF!(f, fval, x, pdata)
    # SER
    residm = resnorm
    resnorm = abs(fval)
    dt *= (residm / resnorm)
    return (x, dt, fval, resnorm)
end

#
# These functions work fine with both scalar and vector equations.
#

function PTCinit(x0, dx, F!, J!, pdt0, maxit, pdata, jfact)
    #
    #   Initialize the iteration.
    #
    n = length(x0)
    x = copy(x0)
    ItRules =
        (dx = dx, f = F!, fp = J!, pdt0 = pdt0, maxit = maxit,  
             pdata = pdata, fact = jfact)
    return (ItRules, x, n)
end

function solhistinit(n, maxit, x)
    #
    # If you are keeping a solution history, make some room for it.
    #
    solhist = zeros(n, maxit + 1)
    @views solhist[:, 1] .= x
    return solhist
end

"""
PTCOK: Figure out idid and errcode
"""
function PTCOK(resnorm, tol, toosoon, ItRules, printerr)
    maxit = ItRules.maxit
    pdt0 = ItRules.pdt0
    errcode = 0
    resfail = (resnorm > tol)
    idid = ~(resfail || toosoon)
    errcode = 0
    if ~idid
        (errcode = PTCError(resnorm, maxit, pdt0, toosoon, tol, printerr))
    end
    return (idid, errcode)
end


"""
PTCOKClose: package the output of ptcsol
"""
function PTCClose(x, FS, ithist, idid, errcode, keepsolhist, solhist = [])
    if keepsolhist
        sizehist = length(ithist)
        return (
            solution = x,
            functionval = FS,
            history = ithist,
            idid = idid,
            errcode = errcode,
            solhist = solhist[:, 1:sizehist],
        )
    else
        return (
            solution = x,
            functionval = FS,
            history = ithist,
            idid = idid,
            errcode = errcode,
        )
    end
end
