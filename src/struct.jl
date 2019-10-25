
mutable struct RangeArray{T,N,AT,RT} <: AbstractArray{T,N}
    data::AT
    ranges::RT
end

function RangeArray(data::AbstractArray{T,N}, ranges::Union{Tuple,Base.RefValue} = axes(data)) where {T,N}
    length(ranges) == N || error("wrong number of ranges")
    all(r -> r isa AbstractVector, ranges) || error("ranges must be AbstractVectors")
    final = (N==1 && ranges isa Tuple) ? Ref(first(ranges)) : ranges
    RangeArray{T, N, typeof(data), typeof(final)}(data, final)
end

Base.size(x::RangeArray) = size(x.data)

Base.axes(x::RangeArray) = axes(x.data)

Base.parent(x::RangeArray) = x.data

ranges(x::RangeArray) = Tuple(x.ranges)
ranges(x::RangeArray{T,N}, d) where {T,N} = d<=N ? x.ranges[d] : Base.OneTo(1)
ranges(x::RangeArray{T,1}, d) where {T,N} = d==1 ? x.ranges[] : Base.OneTo(1)

Base.IndexStyle(A::RangeArray) = IndexCartesian()

for (bget, rget) in [(:getindex, :range_getindex), (:view, :range_view)]
    @eval begin

        @inline function Base.$bget(A::RangeArray, I...)
            @boundscheck checkbounds(A.data, I...)
            data = @inbounds getindex(A.data, I...)

            @boundscheck map(checkbounds, A.ranges, I)
            ranges = @inbounds $rget(A.ranges, I)

            ranges isa Tuple{} ? data : RangeArray(data, ranges)
        end

        $rget(ranges, inds) = filter(r -> r isa AbstractArray, map($bget, ranges, inds))

    end
end

@inline function Base.setindex!(A::RangeArray, val, I...)
    @boundscheck checkbounds(A, I...)
    @inbounds setindex!(A.data, val, I...)
    val
end

"""
    (A::RangeArray)("a", 2.0, :γ) == A[1, 2, 3]
    A(:γ) == view(A, :,:,3)

`RangeArray`s are callable, and this behaves much like indexing,
except using the contents of the ranges, not the integer indices.

When all `ranges(A)` have distinct `eltype`s,
then a single index may be used to indicate a slice.
"""
Base.@propagate_inbounds (A::RangeArray)(args...) = get_from_args(A, args...)

Base.@propagate_inbounds function get_from_args(A, args...)
    ranges = AxisRanges.ranges(A)

    if length(args) == ndims(A)
        inds = map((v,r) -> findindex(v,r), args, ranges)
        # any(inds .=== nothing) && error("no matching entries found!") # very slow!
        # @boundscheck checkbounds(A, inds...) # TODO add methods to checkbounds for nothing?
        # return @inbounds getindex(A, inds...)
        return getindex(A, inds...)


    elseif length(args)==1 && allunique_types(map(eltype, ranges)...)
        d = findfirst(T -> args[1] isa T, eltype.(ranges))
        i = findindex(first(args), ranges[d])
        inds = ntuple(n -> n==d ? i : (:), ndims(A))
        # @boundscheck checkbounds(A, inds...)
        # return @inbounds getindex(A, inds...)
        return getindex(A, inds...)

    end

    if length(args)==1
        error("can only use one entry with all distinct types")
    elseif length(args) != ndims(A)
        error("wrong number of ranges")
    else
        error("can't understand what to do with $args")
    end
end

@generated allunique_types(x, y...) = (x in y) ? false : :(allunique_types($(y...)))
allunique_types(x::DataType) = true

"""
    findindex(key, range)

This is usually `findfirst(isequal(key), range)`,
but understands `findindex(:, range) = range`,
and `findindex(array, range) = intersect(array, range)`.

It also understands functions `findindex(<(4), range) = findall(x -> x<4, range)`,
and selectors like `All(key)` and `Between(lo,hi)`.
"""
findindex(a, r::AbstractArray) = findfirst(isequal(a), r)

findindex(a::Colon, r::AbstractArray) = Colon()

findindex(a::AbstractArray, r::AbstractArray) = intersect(a, r)

findindex(f::Function, r::AbstractArray) = findall(f, r)

"""
    wrapdims(A, :i, :j)
    wrapdims(A, 1:10, ['a', 'b', 'c'])
    wrapdims(A, i=1:10, j=['a', 'b', 'c'])

Function for constructing either a `NamedDimsArray`, a `RangeArray`,
or a nested pair of both. Performs some sanity checks.

When both are present, it makes a `RangeArray{...,NamedDimsArray{...}}`... for now?
"""
wrapdims(A::AbstractArray, n::Symbol, names::Symbol...) =
    NamedDimsArray(A, (n, names...))
wrapdims(A::AbstractArray, r::Union{AbstractVector,Nothing}, ranges::Union{AbstractVector,Nothing}...) =
    RangeArray(A, check_ranges(A, (r, ranges...)))
wrapdims(A::AbstractArray; kw...) =
    # if rand() < 0.5
    #     NamedDimsArray(RangeArray(A, check_ranges(A, values(kw.data))), check_names(A,kw.itr))
    # else
        RangeArray(NamedDimsArray(A, check_names(A, kw.itr)), check_ranges(A, values(kw.data)))
    # end

function check_names(A, names)
    ndims(A) == length(names) || error("wrong number of names")
    names
end

using OffsetArrays

function check_ranges(A, ranges)
    ndims(A) == length(ranges) || error("wrong number of ranges")
    checked = map(enumerate(ranges)) do (d,r)
        r === nothing && return axes(A,d)
        size(A,d) == length(r) || error("wrong length of ranges")
        if axes(A,d) != axes(r,1) # error("range's axis does not match array's")
            r = OffsetArray(r, axes(A,d))
        end
        if eltype(r) == Symbol
            allunique(r...) || error("ranges of Symbols need to be unique")
        end
        r
    end
    ndims(A) == 1 ? Ref(first(checked)) : Tuple(checked)
end
