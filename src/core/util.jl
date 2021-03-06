# ---------   Utility Functions ----------- #

macro VarName(ex::Union{Expr, Symbol})
  # Usage: @VarName x[1,2][1+5][45][3]
  #    return: (:x,[1,2],6,45,3)
  s = string(gensym())
  if isa(ex, Symbol)
    _ = string(ex)
    return :(Symbol($_), Symbol($s))
  elseif ex.head == :ref
    _2 = ex
    _1 = ""
    while _2.head == :ref
      if length(_2.args) > 2
        _1 = "[" * foldl( (x,y)-> "$x, $y", map(string, _2.args[2:end])) * "], $_1"
      else
        _1 = "[" * string(_2.args[2]) * "], $_1"
      end
      _2   = _2.args[1]
      isa(_2, Symbol) && (_1 = ":($_2)" * ", ($_1), Symbol(\"$s\")"; break)
    end
    return esc(parse(_1))
  else
    error("VarName: Mis-formed variable name $(e)!")
  end
end

invlogit{T<:Real}(x::Union{T,Vector{T},Matrix{T}}) = one(T) ./ (one(T) + exp(-x))
logit{T<:Real}(x::Union{T,Vector{T},Matrix{T}}) = log(x ./ (one(T) - x))

# More stable, faster version of rand(Categorical)
function randcat(p::Vector{Float64})
  # if(any(p .< 0)) error("Negative probabilities not allowed"); end
  r, s = rand(), one(Int)
  for j = 1:length(p)
    r -= p[j]
    if(r <= 0.0) s = j; break; end
  end

  s
end

type NotImplementedException <: Exception end

# Numerically stable sum of values represented in log domain.
function logsum(xs::Vector{Float64})
  largest = maximum(xs)
  ys = map(x -> exp(x - largest), xs)

  log(sum(ys)) + largest
end

# KL-divergence
kl(p::Normal, q::Normal) = (log(q.σ / p.σ) + (p.σ^2 + (p.μ - q.μ)^2) / (2 * q.σ^2) - 0.5)

align(x,y) = begin
  if length(x) < length(y)
    z = zeros(y)
    z[1:length(x)] = x
    x = z
  elseif length(x) > length(y)
    z = zeros(x)
    z[1:length(y)] = y
    y = z
  end

  (x,y)
end
