doc"""
    PG(n_particles::Int, n_iters::Int)

Particle Gibbs sampler.

Usage:

```julia
PG(100, 100)
```

Example:

```julia
# Define a simple Normal model with unknown mean and variance.
@model gdemo(x) = begin
  s ~ InverseGamma(2,3)
  m ~ Normal(0,sqrt(s))
  x[1] ~ Normal(m, sqrt(s))
  x[2] ~ Normal(m, sqrt(s))
  return s, m
end

sample(gdemo([1.5, 2]), PG(100, 100))
```
"""
immutable PG <: InferenceAlgorithm
  n_particles           ::    Int         # number of particles used
  n_iters               ::    Int         # number of iterations
  resampler             ::    Function    # function to resample
  resampler_threshold   ::    Float64     # threshold of ESS for resampling
  space                 ::    Set         # sampling space, emtpy means all
  gid                   ::    Int         # group ID
  PG(n1::Int, n2::Int) = new(n1, n2, resampleSystematic, 0.5, Set(), 0)
  function PG(n1::Int, n2::Int, space...)
    space = isa(space, Symbol) ? Set([space]) : Set(space)
    new(n1, n2, resampleSystematic, 0.5, space, 0)
  end
  PG(alg::PG, new_gid::Int) = new(alg.n_particles, alg.n_iters, alg.resampler, alg.resampler_threshold, alg.space, new_gid)
end

Sampler(alg::PG) = begin
  info = Dict{Symbol, Any}()
  info[:logevidence] = []
  Sampler(alg, info)
end

step(model::Function, spl::Sampler{PG}, vi::VarInfo, _::Bool) = step(model, spl, vi)

step(model::Function, spl::Sampler{PG}, vi::VarInfo) = begin
  particles = ParticleContainer{TraceR}(model)

  vi.index = 0; vi.num_produce = 0;  # We need this line cause fork2 deepcopy `vi`.
  ref_particle = isempty(vi) ?
                 nothing :
                 fork2(TraceR(model, spl, vi))

  vi[getretain(vi, 0, spl)] = NULL

  if ref_particle == nothing
    push!(particles, spl.alg.n_particles, spl, vi)
  else
    push!(particles, spl.alg.n_particles-1, spl, vi)
    push!(particles, ref_particle)
  end

  while consume(particles) != Val{:done}
    ess = effectiveSampleSize(particles)
    if ess <= spl.alg.resampler_threshold * length(particles)
      resample!(particles, spl.alg.resampler, ref_particle)
    end
  end

  ## pick a particle to be retained.
  Ws, _ = weights(particles)
  # println(Ws)
  indx = randcat(Ws)
  # println(indx)
  # exit()
  push!(spl.info[:logevidence], particles.logE)
  particles[indx].vi
end

sample(model::Function, alg::PG;
       save_state=false,         # flag for state saving
       resume_from=nothing,      # chain to continue
       reuse_spl_n=0             # flag for spl re-using
      ) = begin

  spl = reuse_spl_n > 0 ?
        resume_from.info[:spl] :
        Sampler(alg)

  @assert typeof(spl.alg) == typeof(alg) "[Turing] alg type mismatch; please use resume() to re-use spl"

  n = reuse_spl_n > 0 ?
      reuse_spl_n :
      alg.n_iters
  samples = Vector{Sample}()

  ## custom resampling function for pgibbs
  ## re-inserts reteined particle after each resampling step
  time_total = zero(Float64)

  vi = resume_from == nothing ?
       VarInfo() :
       resume_from.info[:vi]

  @showprogress 1 "[PG] Sampling..." for i = 1:n
    time_elapsed = @elapsed vi = step(model, spl, vi)
    push!(samples, Sample(vi))
    samples[i].value[:elapsed] = time_elapsed
    time_total += time_elapsed
  end

  println("[PG] Finished with")
  println("  Running time    = $time_total;")

  loge = exp(mean(spl.info[:logevidence]))
  if resume_from != nothing   # concat samples
    unshift!(samples, resume_from.value2...)
    pre_loge = resume_from.weight
    # Calculate new log-evidence
    pre_n = length(resume_from.value2)
    loge = exp((log(pre_loge) * pre_n + log(loge) * n) / (pre_n + n))
  end
  c = Chain(loge, samples)       # wrap the result by Chain

  if save_state               # save state
    save!(c, spl, model, vi)
  end

  c
end

assume{T<:Union{PG,SMC}}(spl::Sampler{T}, dist::Distribution, vn::VarName, _::VarInfo) = begin
  vi = current_trace().vi
  if isempty(spl.alg.space) || vn.sym in spl.alg.space
    vi.index += 1
    if ~haskey(vi, vn)
      r = rand(dist)
      push!(vi, vn, r, dist, spl.alg.gid)
      spl.info[:cache_updated] = CACHERESET # sanity flag mask for getidcs and getranges
      r
    elseif isnan(vi, vn)
      r = rand(dist)
      setval!(vi, vectorize(dist, r), vn)
      setgid!(vi, spl.alg.gid, vn)
      r
    else
      checkindex(vn, vi, spl)
      updategid!(vi, vn, spl)
      vi[vn]
    end
  else
    vi[vn]
  end
end

assume{T<:Union{PG,SMC}}(spl::Void, dists::Vector{T}, vn::VarName, var::Any, vi::VarInfo) =
  error("[Turing] PG and SMC doesn't support vectorizing assume statement")

observe{T<:Union{PG,SMC}}(spl::Sampler{T}, dist::Distribution, value, vi) =
  produce(logpdf(dist, value))

observe{A<:Union{PG,SMC},D<:Distribution}(spl::Sampler{A}, ds::Vector{D}, value::Any, vi::VarInfo) =
  error("[Turing] PG and SMC doesn't support vectorizing observe statement")
