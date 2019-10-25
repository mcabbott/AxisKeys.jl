
function Base.map(f, A::RangeArray)
    data = map(f, A.data)
    RangeArray(data, map(copy, A.ranges))#, copy(A.meta))
end

function Base.collect(x::Base.Generator{<:RangeArray})
    data = collect(Base.Generator(x.f, x.iter.data))
    RangeArray(data, map(copy, x.iter.ranges))#, copy(A.meta))
end

function Base.mapreduce(f, op, A::RangeArray; dims=:) # sum, prod, etc
    B = parent(A)
    dims === Colon() && return mapreduce(f, op, B)

    numerical_dims = hasnames(A) ? NamedDims.dim(names(A), dims) : dims
    C = mapreduce(f, op, B; dims=numerical_dims)

    X = hasnames(A) ? NamedDimsArray(C, names(A)) : C
    if hasranges(A)
        new_ranges = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : ranges(A,d), ndims(A))
        return RangeArray(X, new_ranges)#, copy(A.meta))
    else
        return X
    end
end

function Base.dropdims(A::RangeArray; dims)
    numerical_dims = hasnames(A) ? NamedDims.dim(names(A), dims) : dims
    data = dropdims(A.data; dims=dims)
    ranges = range_skip(A.ranges, numerical_dims...)
    RangeArray(data, ranges)#, A.meta)
end

range_skip(tup::Tuple, d, dims...) = range_skip(
    ntuple(n -> n<d ? tup[n] : tup[n+1], length(tup)-1),
    map(n -> n<d ? n : n-1, dims)...)
range_skip(tup::Tuple) = tup

function Base.permutedims(A::RangeArray, perm)
    numerical_perm = hasnames(A) ? NamedDims.dim(names(A), perm) : perm
    data = permutedims(A.data, numerical_perm)
    new_ranges = ntuple(d -> copy(ranges(A, findfirst(isequal(d), perm))), ndims(A))
    RangeArray(data, new_ranges)#, copy(A.meta))
end

using LinearAlgebra

for (mod, fun, lazy) in [(Base, :permutedims, false),
        (LinearAlgebra, :transpose, true), (LinearAlgebra, :adjoint, true)]
    @eval function $mod.$fun(A::RangeArray)
        data = $mod.$fun(A.data)
        new_ranges = ndims(A)==1 ? (Base.OneTo(1), ranges(A,1)) : reverse(A.ranges)
        RangeArray(data, $(lazy ? :(map(copy, new_ranges)) : :new_ranges))#, $(lazy ? :(A.meta) : :(copy(A.meta))))
    end
end

for fun in [:copy, :deepcopy, :similar, :zero, :one]
    @eval Base.$fun(A::RangeArray) = RangeArray($fun(A.data), map(copy, A.ranges))
end
Base.similar(A::RangeArray, T::Type) = RangeArray(similar(A.data, T), map(copy, A.ranges))
