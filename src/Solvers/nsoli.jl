"""
    nsoli(F!, x0, FS, FPS, Jvec=dirder; rtol=1.e-6, atol=1.e-12,
               maxit=20, lmaxit=5, lsolver="gmres", eta=.1,
               fixedeta=true, Pvec=nothing, pside="left",
               armmax=10, dx = 1.e-7, armfix=false, pdata = nothing,
               printerr = true, keepsolhist = false, stagnationok=false)
)

C. T. Kelley, 2021

Julia versions of the nonlinear solvers from my SIAM books. 
Herewith: nsoli

You must allocate storage for the function and the Krylov basis in advance
--> in the calling program <-- ie. in FS and FPS

Inputs:\n
- F!: function evaluation, the ! indicates that F! overwrites FS, your
    preallocated storage for the function.\n
    So FS=F!(FS,x) or FS=F!(FS,x,pdata) returns FS=F(x)


- x0: initial iterate\n

- FS: Preallocated storage for function. It is an N x 1 column vector\n

- FPS: preallocated storage for the Krylov basis. It is an N x m matrix where
       you plan to take at most m-1 GMRES iterations before a restart. \n

- Jvec: Jacobian vector product, If you leave this out the
    default is a finite difference directional derivative.\n
    So, FP=Jvec(v,FS,x) or FP=Jvec(v,FS,x,pdata) returns FP=F'(x) v. \n
    (v, FS, x) or (v, FS, x, pdata) must be the argument list, 
    even if FP does not need FS.
    One reason for this is that the finite-difference derivative
    does and that is the default in the solver.

- Precision: Lemme tell ya 'bout precision. I designed this code for 
    full precision functions and linear algebra in any precision you want. 
    You can declare FPS as Float64 or Float32 and nsoli 
    will do the right thing. Float16 support is there, but not working well.
    
    If the Jacobian is reasonably well conditioned, you can cut the cost
    of orthogonalization and storage (for GMRES) in half with no loss. 
    There is no benefit if your linear solver is not GMRES or if 
    othogonalization and storage of the Krylov vectors is only a
    small part of the cost of the computation. So if your preconditioner
    is good and you only need a few Krylovs/Newton, reduced precision won't
    help you much.

----------------------

Keyword Arguments (kwargs):\n

rtol and atol: relative and absolute error tolerances\n

maxit: limit on nonlinear iterations\n

lmaxit: limit on linear iterations. If lmaxit > m-1, where FPS has
m columns, and you need more
than m-1 linear iterations, then GMRES will restart. The default is 5.
That default is low because I'm expecting you to have a good preconditioner.\n
--> Restarted GMRES is not ready yet.

lsolver: the linear solver, default = "gmres"\n
Your choices will be "gmres" or "bicgstab". However,
gmres is the only option for now.

eta and fixed eta: eta > 0 or there's an error

The linear solver terminates when ||F'(x)s + F(x) || <= etag || F(x) ||

where 

etag = eta if fixedeta=true

etag = Eisenstat-Walker as implemented in book if fixedeta=false

The default, which may change, is eta=.1, fixedeta=true

Pvec: Preconditioner-vector product. The rules are similar to Jvec
    So, Pv=Pvec(v,x) or Pv=Pvec(v,x,pdata) returns P(x) v where
    P(x) is the preconditioner. You must use x as an input even
    if your preconditioner does not depend on x

armmax: upper bound on step size reductions in line search\n

dx: default = 1.e-7\n
difference increment in finite-difference derivatives
      h=dx*norm(x,Inf)+1.e-8

armfix: default = false\n
The default is a parabolic line search (ie false). Set to true and
the step size will be fixed at .5. Don't do this unless you are doing
experiments for research.\n

pdata:\n 
precomputed data for the function/Jacobian-vector/Preconditioner-vector
products.  Things will go better if you use this rather than hide the data 
in global variables within the module for your function/Jacobian

If you use pdata in any of F!, Jvec, or Pvec, you must use in in all of them.

printerr: default = true\n
I print a helpful message when the solver fails. To suppress that
message set printerr to false.

keepsolhist: default = false\n
Set this to true to get the history of the iteration in the output
tuple. This is on by default for scalar equations and off for systems.
Only turn it on if you have use for the data, which can get REALLY LARGE.

stagnationok: default = false\n
Set this to true if you want to disable the line search and either
observe divergence or stagnation. This is only useful for research
or writing a book.

Output:\n
- A named tuple (solution, functionval, history, stats, idid,
               errcode, solhist)
where

   -- solution = converged result

   -- functionval = F(solution)

   -- history = the vector of residual norms (||F(x)||) for the iteration

   -- stats = named tuple of the history of (ifun, ijvec, iarm), the number
of functions/Jacobian-vector prods/steplength reductions at each iteration.

I do not count the function values for a finite-difference derivative
because they count toward a Jacobian-vector product.

  -- idid=true if the iteration succeeded and false if not.

  -- errcode = 0 if if the iteration succeeded

        = -1 if the initial iterate satisfies the termination criteria

        = 10 if no convergence after maxit iterations

        = 1  if the line search failed

   -- solhist:\n
      This is the entire history of the iteration if you've set
      keepsolhist=true\n

solhist is an N x K array where N is the length of x and K is the number of
iteration + 1. So, for scalar equations, it's a row vector.

------------------------

# Examples

#### Simple 2D problem. You should get the same results as for nsol.jl because
GMRES will solve the equation for the step exactly in two iterations. Finite
difference Jacobians and analytic Jacobian-vector products for full precision
and finite difference Jacobian-vector products for single precision.

```jldoctest
julia> function f!(fv,x)
       fv[1]=x[1] + sin(x[2])
       fv[2]=cos(x[1]+x[2])
       end
f! (generic function with 1 method)

julia> function JVec(v, fv, x)
       jvec=zeros(2,);
       p=-sin(x[1]+x[2])
       jvec[1]=v[1]+cos(x[2])*v[2]
       jvec[2]=p*(v[1]+v[2])
       return jvec
       end
JVec (generic function with 1 method)

julia> x0=ones(2,); fv=zeros(2,); jv=zeros(2,2); jv32=zeros(Float32,2,2);

julia> jvs=zeros(2,3); jvs32=zeros(Float32,2,3);

julia> nout=nsol(f!,x0,fv,jv; sham=1);

julia> kout=nsoli(f!,x0,fv,jvs,JVec; fixedeta=true, eta=.1, lmaxit=2);

julia> kout32=nsoli(f!,x0,fv,jvs32; fixedeta=true, eta=.1, lmaxit=2);

julia> [nout.history kout.history kout32.history]
5×3 Array{Float64,2}:
 1.88791e+00  1.88791e+00  1.88791e+00
 2.43119e-01  2.43120e-01  2.43119e-01
 1.19231e-02  1.19231e-02  1.19231e-02
 1.03266e-05  1.03261e-05  1.03273e-05
 1.46416e-11  1.40862e-11  1.45457e-11
```



"""
function nsoli(
    F!,
    x0,
    FS,
    FPS,
    Jvec = dirder;
    rtol = 1.e-6,
    atol = 1.e-12,
    maxit = 20,
    lmaxit = 5,
    lsolver = "gmres",
    eta = 0.1,
    fixedeta = true,
    Pvec = nothing,
    pside = "left",
    armmax = 10,
    dx = 1.e-7,
    armfix = false,
    pdata = nothing,
    printerr = true,
    keepsolhist = false,
    stagnationok = false,
)
    itc = 0
    idid = true
    iline = false
    #
    #   If I'm letting the iteration stagnate and turning off the
    #   linesearch, then the line search cannot fail.
    #
    stagflag = stagnationok && (armmax == 0)
    #=
    Named tuple with the iteration data. This makes communiction
    with the linear solvers and the line search easier.
    =#
    (ItRules, x, n) = Newton_Krylov_Init(
        x0,
        dx,
        F!,
        Jvec,
        Pvec,
        pside,
        lsolver,
        eta,
        fixedeta,
        armmax,
        armfix,
        maxit,
        lmaxit,
        printerr,
        pdata,
    )
    keepsolhist ? (solhist = solhistinit(n, maxit, x)) : (solhist = [])
    #
    # First Evaluation of the function. Initialize the iteration stats.
    # Fix the tolerances for convergence and define the derivative FPF
    # outside of the main loop for scoping.
    #   
    FS = EvalF!(F!, FS, x, pdata)
    resnorm = norm(FS)
    tol = rtol * resnorm + atol
    FPF = []
    ItData = ItStats(resnorm)
    newiarm = -1
    newfun = 0
    newjac = 0
    residratio = 1.0
    armstop = true
    etag = eta
    #
    # Preallocate a few vectors for the step, trial step, trial function
    #
    step = copy(x)
    xt = copy(x)
    FT = copy(x)
    #
    # If the initial iterate satisfies the termination criteria, tell me.
    #
    toosoon = (resnorm <= tol)
    #
    # The main loop stops on convergence, too many iterations, or a
    # line search failure after a derivative evaluation.
    #
    while resnorm > tol && itc < maxit && (armstop || stagnationok)
        #   
        # Evaluate and factor the Jacobian.   
        #
        newfun = 0
        newjac = 0
        #
        #
        # The GMRES solver will do the orthogonalization in lower
        # precision. I've tested Float32, but see the docstrings
        # for all the caveats. This is not the slam dunk it was
        # for Gaussian elimination on dense matrices.
        #
        step .*= 0.0
        etag = forcing(itc, residratio, etag, ItRules, tol, resnorm)
        kout = Krylov_Step!(step, x, FS, FPS, ItRules, etag)
        step = kout.step
        #
        # For GMRES you get 1 jac-vec per iteration and there is no jac-vec
        # for the initial inner iterate of zero
        #
        newjac = kout.Lstats.lits
        linok = kout.Lstats.idid
        linok || println("Linear solver did not meet termination criterion.
          This does not mean the nonlinear solver will fail.")
        #
        # Compute the trial point, evaluate F and the residual norm.     
        # The derivative is never old for Newton-Krylov
        #
        AOUT = armijosc(xt, x, FT, FS, step, resnorm, ItRules, false)
        #
        # update solution/function value
        #
        x .= AOUT.ax
        FS .= AOUT.afc
        #
        # If the line search fails 
        # stop the iteration. Print an error message unless
        # stagnationok == true
        #
        armstop = AOUT.idid
        iline = ~armstop && ~stagflag
        #
        # Keep the books.
        #
        residm = resnorm
        resnorm = AOUT.resnorm
        residratio = resnorm / residm
        updateStats!(ItData, newfun, newjac, AOUT)
        newiarm = AOUT.aiarm
        itc += 1
        keepsolhist && (@views solhist[:, itc+1] .= x)
        #        ~keepsolhist || (@views solhist[:, itc+1] .= x)
    end
    solution = x
    functionval = FS
    (idid, errcode) = NewtonOK(resnorm, iline, tol, toosoon, itc, ItRules)
    stats = (ifun = ItData.ifun, ijac = ItData.ijac, iarm = ItData.iarm)
    newtonout =
        NewtonClose(x, FS, ItData.history, stats, idid, errcode, keepsolhist, solhist)
    return newtonout
    #return (solution=x, functionval=FS, history=ItData.history)
end
