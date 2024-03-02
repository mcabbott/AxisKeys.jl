module StatsBaseExt

using AxisKeys: KeyedArray, KeyedMatrix, NamedDims, NamedDimsArray, axiskeys, dimnames, keyless_unname, hasnames
using StatsBase
using StatsBase.Statistics

# Support some of the weighted statistics function in StatsBase
# NOTES:
# - Ambiguity errors are still possible for weights with overly specific methods (e.g., UnitWeights)
# - Ideally, when the weighted statistics is moved to Statistics.jl we can remove this entire file.
#   https://github.com/JuliaLang/Statistics.jl/pull/2
function Statistics.mean(A::KeyedArray, wv::AbstractWeights; dims=:, kwargs...)
    dims === Colon() && return mean(parent(A), wv; kwargs...)
    numerical_dims = NamedDims.dim(A, dims)
    data = mean(parent(A), wv; dims=numerical_dims, kwargs...)
    new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
    return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
end

# var and std are separate cause they don't use the dims keyword and we need to set corrected=true
for fun in [:var, :std]
    @eval function Statistics.$fun(A::KeyedArray, wv::AbstractWeights; dims=:, corrected=true, kwargs...)
        dims === Colon() && return $fun(parent(A), wv; kwargs...)
        numerical_dims = NamedDims.dim(A, dims)
        data = $fun(parent(A), wv, numerical_dims; corrected=corrected, kwargs...)
        new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
        return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
    end
end

for fun in [:cov, :cor]
    @eval function Statistics.$fun(A::KeyedMatrix, wv::AbstractWeights; dims=1, kwargs...)
        d = NamedDims.dim(A, dims)
        data = $fun(keyless_unname(A), wv, d; kwargs...)
        L1 = dimnames(A, 3 - d)
        data2 = hasnames(A) ? NamedDimsArray(data, (L1, L1)) : data
        K1 = axiskeys(A, 3 - d)
        KeyedArray(data2, (copy(K1), copy(K1)))
    end
end

# scattermat is a StatsBase function and takes dims as a kwarg
function StatsBase.scattermat(A::KeyedMatrix, wv::AbstractWeights; dims=1, kwargs...)
    d = NamedDims.dim(A, dims)
    data = scattermat(keyless_unname(A), wv; dims=d, kwargs...)
    L1 = dimnames(A, 3 - d)
    data2 = hasnames(A) ? NamedDimsArray(data, (L1, L1)) : data
    K1 = axiskeys(A, 3 - d)
    KeyedArray(data2, (copy(K1), copy(K1)))
end

for fun in (:std, :var, :cov)
    full_name = Symbol("mean_and_$fun")
    @eval StatsBase.$full_name(A::KeyedMatrix, wv::Vararg{AbstractWeights}; dims=:, corrected::Bool=true, kwargs...) =
        (
            mean(A, wv...; dims=dims, kwargs...),
            $fun(A, wv...; dims=dims, corrected=corrected, kwargs...)
        )
end

end
