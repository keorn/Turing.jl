Get Started
=========

Turing is a Julia library for probabilistic programming. A Turing
probabilistic program is just a normal Julia program, wrapped in a
``@model`` macro, that uses some of the special macros listed below.
Available inference methods include Importance Sampling, Sequential
Monte Carlo, Particle Gibbs.

Authors: `Hong Ge <http://mlg.eng.cam.ac.uk/hong/>`__, `Adam
Scibior <http://mlg.eng.cam.ac.uk/?portfolio=adam-scibior>`__, `Matej
Balog <http://mlg.eng.cam.ac.uk/?portfolio=matej-balog>`__, `Zoubin
Ghahramani <http://mlg.eng.cam.ac.uk/zoubin/>`__

Relevant papers
~~~~~~~~~~~~~~~

1. Ghahramani, Zoubin. "Probabilistic machine learning and artificial
   intelligence." Nature 521, no. 7553 (2015): 452-459.
   (`pdf <http://www.nature.com/nature/journal/v521/n7553/full/nature14541.html>`__)
2. Ge, Hong, Adam Scibior, and Zoubin Ghahramani "Turing: A fast
   imperative probabilistic programming language." (In submission).

Example
~~~~~~~

.. code:: julia

    @model gaussdemo begin
      # Define a simple Normal model with unknown mean and variance.
      @assume s ~ InverseGamma(2,3)
      @assume m ~ Normal(0,sqrt(s))
      @observe 1.5 ~ Normal(m, sqrt(s))
      @observe 2.0 ~ Normal(m, sqrt(s))
      @predict s m
    end

Installation
------------

You will need Julia 0.5 (or 0.4; but 0.5 is recommended), which you can get from the official Julia
`website <http://julialang.org/downloads/>`__. We recommend that you
install a pre-compiled package, as Turing may not work correctly with
Julia built form source.

Turing is an officially registered Julia package, so the following
should work:

.. code:: julia

    Pkg.update()
    Pkg.add("Turing")
    Pkg.test("Turing")

If Turing can not be located or you want to use the latest version of Turing, you can try the following instead:

.. code:: julia

    Pkg.clone("https://github.com/yebai/Turing.jl")
    Pkg.build("Turing")
    Pkg.test("Turing")

If all tests pass, you're ready to start using Turing.

Modelling API
-------------

A probabilistic program is Julia code wrapped in a ``@model`` macro. It
can use arbitrary Julia code, but to ensure correctness of inference it
should not have external effects or modify global state. Stack-allocated
variables are safe, but mutable heap-allocated objects may lead to
subtle bugs when using task copying. To help avoid those we provide a
Turing-safe datatype ``TArray`` that can be used to create mutable
arrays in Turing programs.

For probabilistic effects, Turing programs should use the following
macros:

``@assume x ~ distr`` where ``x`` is a symbol and ``distr`` is a
distribution. Inside the probabilistic program this puts a random
variable named ``x``, distributed according to ``distr``, in the current
scope. ``distr`` can be a value of any type that implements
``rand(distr)``, which samples a value from the distribution ``distr``.

``@observe y ~ distr`` This is used for conditioning in a style similar
to Anglican. Here ``y`` should be a value that is observed to have been
drawn from the distribution ``distr``. The likelihood is computed using
``pdf(distr,y)`` and should always be positive to ensure correctness of
inference algorithms. The observe statements should be arranged so that
every possible run traverses all of them in exactly the same order. This
is equivalent to demanding that they are not placed inside stochastic
control flow.

``@predict x`` Registers the current value of ``x`` to be inspected in
the results of inference.

Inference API
-------------

Inference methods are functions which take the probabilistic program as
one of the arguments.

.. code:: julia

    #  run sampler, collect results
    chain = sample(gaussdemo, SMC(500))
    chain = sample(gaussdemo, PG(10,500))

Task copying
------------

Turing `copies <https://github.com/JuliaLang/julia/issues/4085>`__ Julia
tasks to deliver efficient inference algorithms, but it also provides
alternative slower implementation as a fallback. Task copying is enabled
by default. Task copying requires building a small C program, which
should be done automatically on Linux and Mac systems that have GCC and
Make installed.

.. |Build Status| image:: https://travis-ci.org/yebai/Turing.jl.svg?branch=master
   :target: https://travis-ci.org/yebai/Turing.jl
.. |Build status| image:: https://ci.appveyor.com/api/projects/status/fvgi21998e1tfx0d/branch/master?svg=true
   :target: https://ci.appveyor.com/project/yebai/turing-jl/branch/master
.. |Coverage Status| image:: https://coveralls.io/repos/github/yebai/Turing.jl/badge.svg?branch=master
   :target: https://coveralls.io/github/yebai/Turing.jl?branch=master
.. |Turing| image:: http://pkg.julialang.org/badges/Turing_0.4.svg
   :target: http://pkg.julialang.org/?pkg=Turing
.. |Gitter| image:: https://badges.gitter.im/gitterHQ/gitter.svg
   :target: https://gitter.im/Turing-jl/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge