using Base: @propagate_inbounds, OneTo

mutable struct RangeArray{T,N,AT,RT} <: AbstractArray{T,N}
    data::AT
    ranges::RT
end

RangeVector{T,AT,RT} = RangeArray{T,1,AT,RT}

function RangeArray(data::AbstractArray{T,N}, ranges::Union{Tuple,Base.RefValue} = axes(data)) where {T,N}
    length(ranges) == N || error("wrong number of ranges")
    all(r -> r isa AbstractVector, ranges) || error("ranges must be AbstractVectors")
    final = (N==1 && ranges isa Tuple) ? Ref(first(ranges)) : ranges
    RangeArray{T, N, typeof(data), typeof(final)}(data, final)
end

Base.size(x::RangeArray) = size(x.data)

Base.axes(x::RangeArray) = axes(x.data)

Base.parent(x::RangeArray) = x.data

ranges(x::RangeArray) = _Tuple(x.ranges)
ranges(x::RangeArray{T,N}, d::Int) where {T,N} = d<=N ? x.ranges[d] : OneTo(1)
ranges(x::RangeArray{T,1}, d::Int) where {T} = d==1 ? x.ranges[] : OneTo(1)

Base.IndexStyle(A::RangeArray) = IndexCartesian()

for (bget, rget) in [(:getindex, :range_getindex), (:view, :range_view)]
    @eval begin

        @inline function Base.$bget(A::RangeArray, I::Integer...)
            # @boundscheck println("boundscheck getindex/view integers $I")
            @boundscheck checkbounds(parent(A), I...)
            @inbounds Base.$bget(parent(A), I...)
        end

        @inline function Base.$bget(A::RangeArray, I::CartesianIndex)
            # @boundscheck println("boundscheck getindex/view CartesianIndex $I")
            @boundscheck checkbounds(parent(A), I)
            @inbounds Base.$bget(parent(A), I)
        end

        @inline @propagate_inbounds function Base.$bget(A::RangeArray, I...)
            # @boundscheck println("boundscheck getindex/view general $I")
            @boundscheck checkbounds(A.data, I...)
            data = @inbounds Base.$bget(parent(A), I...)

            @boundscheck map(checkbounds, A.ranges, I)
            ranges = $rget(A.ranges, I)

            ranges isa Tuple{} ? data : RangeArray(data, ranges)
        end

        @inline function $rget(ranges, inds)
            got = map(ranges, inds) do r,i
                i isa Integer ? nothing : @inbounds Base.$bget(r,i)
            end
            filter(r -> r isa AbstractArray, got)
        end

    end
end

@inline @propagate_inbounds function Base.setindex!(A::RangeArray, val, I...)
    # @boundscheck println("boundscheck setindex! $I")
    @boundscheck checkbounds(A, I...)
    @inbounds setindex!(A.data, val, I...)
    val
end

"""
    (A::RangeArray)("a", 2.0, :γ) == A[1, 2, 3]
    A(:γ) == A[:, :, 3]

`RangeArray`s are callable, and this behaves much like indexing,
except using the contents of the ranges, not the integer indices.

When all `ranges(A)` have distinct `eltype`s,
then a single index may be used to indicate a slice.
"""
@inline @propagate_inbounds (A::RangeArray)(args...) = getkey(A, args...)

@inline function getkey(A, args...)
    if length(args) == ndims(A)
        inds = map(findindex, args, ranges(A))
        # @boundscheck println("boundscheck getkey $args -> $inds")
        @boundscheck checkbounds(A, inds...)
        return @inbounds getindex(A, inds...)

    elseif length(args)==1 && allunique_types(map(eltype, ranges(A))...)
        arg = first(args)
        rtypes = map(eltype, ranges(A))

        d = findfirst(T -> arg isa T, rtypes) # First look for direct match

        if isnothing(d)
            d = findfirst(T -> arg isa supertype(T), rtypes)
            if arg isa Base.Fix2 || hasproperty(arg, :x) # Next try for a function
                d = findfirst(T -> arg.x isa T, rtypes)
            elseif arg isa Selector
                d = findfirst(T -> eltype(arg) <: T, rtypes)
            end
            isnothing(d) && error("can't find which dimension for $args")
        end

        i = findindex(first(args), ranges(A,d))
        inds = ntuple(n -> n==d ? i : (:), ndims(A))
        # @boundscheck println("boundscheck getkey $args -> $inds")
        @boundscheck checkbounds(A, inds...)
        return @inbounds getindex(A, inds...)

    end

    if length(args)==1
        error("can only use one key when all ranges have distinct eltypes")
    elseif length(args) != ndims(A)
        error("wrong number of keys")
    else
        error("can't understand what to do with $args")
    end
end

Base.@propagate_inbounds function setkey!(A, val, args...)
    length(args) == ndims(A) || error("wrong number of keys")
    inds = map((v,r) -> findindex(v,r), args, ranges(A))
    setindex!(A, val, inds...)
end

@generated allunique_types(x, y...) = (x in y) ? false : :(allunique_types($(y...)))
allunique_types(x::DataType) = true

# https://docs.julialang.org/en/v1/base/arrays/#Base.to_indices
"""
    findindex(key, range)

This is usually `findfirst(isequal(key), range)`,
but understands `findindex(:, range) = range`,
and `findindex(array, range) = intersect(array, range)`.

It also understands functions `findindex(<(4), range) = findall(x -> x<4, range)`,
and selectors like `All(key)` and `Between(lo,hi)`.
"""
@inline function findindex(a, r::AbstractArray)
    i = findfirst(isequal(a), r)
    i === nothing && error("could not find key $a in range $r")
    i
end

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
wrapdims(A::AbstractArray, r::Union{AbstractVector,Nothing}, ranges::Union{AbstractVector,Nothing}...) =
    RangeArray(A, check_ranges(A, (r, ranges...)))

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
