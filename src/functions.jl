
function Base.map(f, A::RangeArray)
    data = map(f, parent(A))
    RangeArray(data, map(copy,A.ranges))#, copy(A.meta))
end
for fun in [:map, :map!], (T, S) in [ (:RangeArray, :RangeArray),
        (:RangeArray, :AbstractArray), (:AbstractArray, :RangeArray),
        (:RangeArray, :NamedDimsArray), (:NamedDimsArray, :RangeArray)] # for ambiguities

    @eval function Base.$fun(f, A::$T, B::$S, Cs::AbstractArray...)
        data = $fun(f, rangeless(A), rangeless(B), rangeless.(Cs)...)
        new_ranges = unify_ranges(ranges_or_axes(A), ranges_or_axes(B), ranges_or_axes.(Cs)...)
        RangeArray(data, map(copy, new_ranges)) # copy sometimes wasteful for map!, but OK.
    end
end

using Base: Generator

function Base.collect(x::Generator{<:RangeArray})
    data = collect(Generator(x.f, x.iter.data))
    RangeArray(data, map(copy, x.iter.ranges))#, copy(A.meta))
end
function Base.collect(x::Generator{<:Iterators.Enumerate{<:RangeArray}})
    data = collect(Generator(x.f, enumerate(x.iter.itr.data)))
    RangeArray(data, map(copy, x.iter.itr.ranges))
end
function Base.collect(x::Generator{<:Iterators.ProductIterator{<:Tuple{RangeArray,Vararg{Any}}}})
    data = collect(Generator(x.f, Iterators.product(rangeless.(x.iter.iterators)...)))
    all_ranges = tuple_flatten(ranges_or_axes.(x.iter.iterators)...)
    RangeArray(data, map(copy, all_ranges))
end

tuple_flatten(x::Tuple, ys::Tuple...) = (x..., tuple_flatten(ys...)...)
tuple_flatten() = ()

function Base.mapreduce(f, op, A::RangeArray; dims=:) # sum, prod, etc
    dims === Colon() && return mapreduce(f, op, parent(A))
    numerical_dims = hasnames(A) ? NamedDims.dim(names(A), dims) : dims
    data = mapreduce(f, op, parent(A); dims=numerical_dims)
    new_ranges = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : ranges(A,d), ndims(A))
    return RangeArray(data, new_ranges)#, copy(A.meta))
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

for (T, S) in [(:RangeVecOrMat, :RangeVecOrMat), # RangeArray gives ambiguities
    (:RangeVecOrMat, :AbstractVecOrMat), (:AbstractVecOrMat, :RangeVecOrMat)]

    @eval function Base.vcat(A::$T, B::$S, Cs::AbstractVecOrMat...)
        data = vcat(rangeless(A), rangeless(B), rangeless.(Cs)...)
        new_1 = range_vcat(ranges_or_axes(A,1), ranges_or_axes(B,1), ranges_or_axes.(Cs,1)...)
        new_ranges = ndims(A) == 1 ? Ref(new_1) :
            (new_1, who_wins(ranges_or_axes(A,2), ranges_or_axes(B,2), ranges_or_axes.(Cs,2)...))
        RangeArray(data, map(copy, new_ranges))
    end

    @eval function Base.hcat(A::$T, B::$S, Cs::AbstractVecOrMat...)
        data = hcat(rangeless(A), rangeless(B), rangeless.(Cs)...)
        new_1 = who_wins(ranges_or_axes(A,1), ranges_or_axes(B,1), ranges_or_axes.(Cs,1)...)
        new_2 = ndims(A) == 1 ? axes(data,2) :
            range_vcat(ranges_or_axes(A,2), ranges_or_axes(B,2), ranges_or_axes.(Cs,2)...)
        RangeArray(data, map(copy, (new_1, new_2)))
    end

end
range_vcat(a::AbstractVector, b::AbstractVector) = vcat(a,b)
range_vcat(a::Base.OneTo, b::Base.OneTo) = Base.OneTo(a.stop + b.stop)
range_vcat(a,b,cs...) = range_vcat(range_vcat(a,b),cs...)

function Base.sort(A::RangeArray; dims, kw...)
    dims′ = hasnames(A) ? NamedDims.dim(names(A), dims) : dims
    data = sort(parent(A); dims=dims′, kw...)
    # sorts each (say) col independently, thus range along them loses meaning.
    new_ranges = ntuple(d -> d==dims′ ? OneTo(size(A,d)) : ranges(A,d), ndims(A))
    RangeArray(data, new_ranges)
end
function Base.sort(A::RangeVector; kw...)
    perm = sortperm(parent(A); kw...)
    RangeArray(parent(A)[perm], (ranges(A,1)[perm],))
end

function Base.sortslices(A::RangeArray; dims, kw...)
    dims′ = hasnames(A) ? NamedDims.dim(names(A), dims) : dims
    data = sortslices(parent(A); dims=dims′, kw...)
    # It would be nice to sort the range to match, but there is no sortpermslices.
    # https://github.com/davidavdav/NamedArrays.jl/issues/79 constructs something
end

Base.filter(f, A::RangeVector) = getindex(A, map(f, parent(A)))
Base.filter(f, A::RangeArray) = filter(f, parent(A))

using LinearAlgebra

for (mod, fun, lazy) in [(Base, :permutedims, false),
        (LinearAlgebra, :transpose, true), (LinearAlgebra, :adjoint, true)]
    @eval function $mod.$fun(A::RangeArray)
        data = $mod.$fun(A.data)
        new_ranges = ndims(A)==1 ? (Base.OneTo(1), ranges(A,1)) :
            ndims(data)==1 ? (ranges(A,2),) :
            reverse(ranges(A))
        RangeArray(data, $(lazy ? :(map(copy, new_ranges)) : :new_ranges))#, $(lazy ? :(A.meta) : :(copy(A.meta))))
    end
end

Base.reshape(A::RangeArray, dims::Union{Colon, Int64}...) = reshape(parent(A), dims...)

for fun in [:copy, :deepcopy, :similar, :zero, :one]
    @eval Base.$fun(A::RangeArray) = RangeArray($fun(A.data), map(copy, A.ranges))
end
Base.similar(A::RangeArray, T::Type) = RangeArray(similar(A.data, T), map(copy, A.ranges))
Base.similar(A::RangeArray, T::Type, dims::Int...) = similar(A.data, T, dims...)
Base.similar(A::RangeArray, dims::Int...) = similar(A.data, dims...)

for fun in [:(==), :isequal, :isapprox]
    @eval function Base.$fun(A::RangeArray, B::RangeArray; kw...)
        # Ideally you would pass isapprox(, atol) into unifiable_ranges?
        unifiable_ranges(ranges(A), ranges(B)) || return false
        return $fun(parent(A), parent(B); kw...)
    end
end
