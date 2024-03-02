module StatisticsExt

using AxisKeys: KeyedArray, KeyedMatrix, NamedDims, axiskeys
using Statistics

for fun in [:mean, :std, :var] # These don't use mapreduce, but could perhaps be handled better?
    @eval function Statistics.$fun(A::KeyedArray; dims=:, kwargs...)
        dims === Colon() && return $fun(parent(A); kwargs...)
        numerical_dims = NamedDims.dim(A, dims)
        data = $fun(parent(A); dims=numerical_dims, kwargs...)
        new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
        return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
    end
end

# Handle function interface for `mean` only
if VERSION >= v"1.3"
    @eval function Statistics.mean(f, A::KeyedArray; dims=:, kwargs...)
        dims === Colon() && return mean(f, parent(A); kwargs...)
        numerical_dims = NamedDims.dim(A, dims)
        data = mean(f, parent(A); dims=numerical_dims, kwargs...)
        new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
        return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
    end
end

for fun in [:cov, :cor] # Returned the axes work are different for cov and cor
    @eval function Statistics.$fun(A::KeyedMatrix; dims=1, kwargs...)
        numerical_dim = NamedDims.dim(A, dims)
        data = $fun(parent(A); dims=numerical_dim, kwargs...)
        # Use same remaining axis for both dimensions of data
        rem_key = axiskeys(A, 3-numerical_dim)
        KeyedArray(data, (copy(rem_key), copy(rem_key)))
    end
end

end
