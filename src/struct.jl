using Base: @propagate_inbounds, OneTo, RefValue

struct RangeArray{T,N,AT,RT} <: AbstractArray{T,N}
    data::AT
    ranges::RT
end

const RangeVector{T,AT,RT} = RangeArray{T,1,AT,RT}
const RangeMatrix{T,AT,RT} = RangeArray{T,2,AT,RT}
const RangeVecOrMat{T,AT,RT} = Union{RangeVector{T,AT,RT}, RangeMatrix{T,AT,RT}}

function RangeArray(data::AbstractArray{T,N}, ranges::Union{Tuple,RefValue} = axes(data)) where {T,N}
    length(ranges) == N || error("wrong number of ranges")
    all(r -> r isa AbstractVector, ranges) || error("ranges must be AbstractVectors")
    final = (N==1 && ranges isa Tuple) ? Ref(first(ranges)) : ranges
    RangeArray{T, N, typeof(data), typeof(final)}(data, final)
end

# RangeArray(data::AbstractVector, ref::RefValue{<:AbstractVector}) =
#     RangeArray{eltype(data), 1, typeof(data), typeof(ref)}(data, ref)
# RangeArray(data::AbstractVector, arr::AbstractVector) =
#     RangeArray{eltype(data), 1, typeof(data), typeof(Ref(arr))}(data, Ref(arr))

Base.size(x::RangeArray) = size(parent(x))

Base.axes(x::RangeArray) = axes(parent(x))

Base.parent(x::RangeArray) = getfield(x, :data)
rangeless(x::RangeArray) = parent(x)
rangeless(x) = x

ranges(x::RangeArray) = getfield(x, :ranges)
ranges(x::RangeVector) = tuple(getindex(getfield(x, :ranges)))
ranges(x::RangeArray, d::Int) = d<=ndims(x) ? getindex(ranges(x), d) : OneTo(1)
ranges(x::RangeVector, d::Int) = d==1 ? getindex(getfield(x, :ranges)) : OneTo(1)

Base.IndexStyle(A::RangeArray) = IndexCartesian()

for (bget, rget, cpy) in [(:getindex, :range_getindex, :copy), (:view, :range_view, :identity)]
    @eval begin

        @inline function Base.$bget(A::RangeArray, I::Integer...)
            # @boundscheck println("boundscheck getindex/view integers $I")
            @boundscheck checkbounds(parent(A), I...)
            @inbounds Base.$bget(parent(A), I...)
        end

        @inline function Base.$bget(A::RangeArray, I::Union{Colon, CartesianIndex})
            # @boundscheck println("boundscheck getindex/view CartesianIndex $I")
            @boundscheck checkbounds(parent(A), I)
            @inbounds Base.$bget(parent(A), I)
        end

        @inline @propagate_inbounds function Base.$bget(A::RangeArray, I...)
            # @boundscheck println("boundscheck getindex/view general $I")
            @boundscheck checkbounds(parent(A), I...)
            data = @inbounds Base.$bget(parent(A), I...)

            @boundscheck map(checkbounds, ranges(A), I)
            new_ranges = $rget(ranges(A), I)

            new_ranges isa Tuple{} ? data : RangeArray(data, new_ranges)
        end

        @inline function $rget(ranges, inds)
            got = map(ranges, inds) do r,i
                i isa Integer       && return nothing
                i isa Colon         && return $cpy(r)        # avoids view([1,2,3], :)
                r isa AbstractRange && return getindex(r,i)  # don't make views of 1:10
                return @inbounds $bget(r,i)
            end
            filter(r -> r isa AbstractArray, got)
        end

    end
end

@inline @propagate_inbounds function Base.setindex!(A::RangeArray, val, I...)
    # @boundscheck println("boundscheck setindex! $I")
    @boundscheck checkbounds(A, I...)
    @inbounds setindex!(parent(A), val, I...)
    val
end

"""
    (A::RangeArray)("a", 2.0, :γ) == A[1, 2, 3]
    A(:γ) == view(A, :, :, 3)

`RangeArray`s are callable, and this behaves much like indexing,
except that it searches for the given keys in `ranges(A)`,
instead of `axes(A)` for indices.

A single key may be used to indicate a slice, provided that its type
only matches the eltype of one `ranges(A,d)`.
You can also slice explicitly with `A("a", :, :)`, both of these return a `view`.

Also accepts functions like `A(<=(2.0))` and selectors,
see `Nearest` and `Index`.
"""
@inline @propagate_inbounds (A::RangeArray)(args...) = getkey(A, args...)

@inline function getkey(A, args...)
    if length(args) == ndims(A)
        inds = map(findindex, args, ranges(A))
        # @boundscheck println("boundscheck getkey $args -> $inds")
        @boundscheck checkbounds(A, inds...)
        return @inbounds get_or_view(A, inds...)

    elseif length(args)==1
        arg = first(args)
        rtypes = map(eltype, ranges(A))

        ds = findall(T -> arg isa T, rtypes) # First look for direct match
        if isempty(ds)
            if arg isa Base.Fix2 || hasproperty(arg, :x) # Next try for a function
                ds = findall(T -> arg.x isa T, rtypes)
            elseif arg isa Selector
                ds = findall(T -> eltype(arg) <: T, rtypes)
            else
                ds = findall(T -> arg isa supertype(T), rtypes) # esp. for AbstractString
            end
            isempty(ds) && error("can't find which dimension for $args")
        end
        length(ds) >= 2 && error(
            "key $arg is ambiguous, its type matches dimensions $(Tuple(ds))")

        d = first(ds)
        i = findindex(arg, ranges(A,d))
        inds = ntuple(n -> n==d ? i : (:), ndims(A))
        # @boundscheck println("boundscheck getkey $args -> $inds")
        @boundscheck checkbounds(A, inds...)
        return @inbounds view(A, inds...)

    end

    if length(args) != ndims(A)
        error("wrong number of keys: got $(length(args)) arguments, expected ndims(A) = $(ndims(A))")
    else
        error("can't understand what to do with $args, sorry")
    end
end

@propagate_inbounds get_or_view(A, inds::Integer...) = getindex(A, inds...)
@propagate_inbounds get_or_view(A, inds...) = view(A, inds...)

@propagate_inbounds function setkey!(A, val, args...)
    length(args) == ndims(A) || error("wrong number of keys")
    inds = map((v,r) -> findindex(v,r), args, ranges(A))
    setindex!(A, val, inds...)
end

# https://docs.julialang.org/en/v1/base/arrays/#Base.to_indices
"""
    findindex(key, range)

This is usually `findfirst(isequal(key), range)`,
but understands `findindex(:, range) = range`,
and `findindex(array, range)`.

It also understands functions `findindex(<(4), range) = findall(x -> x<4, range)`,
and selectors like `Nearest(key)` and `Between(lo,hi)`.
"""
@inline function findindex(a, r::AbstractArray)
    i = findfirst(isequal(a), r)
    i === nothing && error("could not find key $a in range $r")
    i
end

findindex(a::Colon, r::AbstractArray) = Colon()

findindex(a::AbstractArray, r::AbstractArray) = [findfirst(isequal(x), r) for x in a]

findindex(f::Function, r::AbstractArray) = findall(f, r)

"""
    wrapdims(A, :i, :j)
    wrapdims(A, 1:10, ['a', 'b', 'c'])
    wrapdims(A, i=1:10, j=['a', 'b', 'c'])

Function for constructing either a `NamedDimsArray`, a `RangeArray`,
or a nested pair of both.
Performs some sanity checks which are skipped by `RangeArray` constructor.
Giving `nothing` as a range will result in `ranges(A,d) == axes(A,d)`.

By default it wraps in this order: `RangeArray{...,NamedDimsArray{...}}`.
This tests a flag `AxisRanges.OUTER[] == :RangeArray` which you can change.
"""
wrapdims(A::AbstractArray, r::Union{AbstractVector,Nothing}, ranges::Union{AbstractVector,Nothing}...) =
    RangeArray(A, check_ranges(A, (r, ranges...)))

using OffsetArrays

function check_ranges(A, ranges)
    ndims(A) == length(ranges) || error("wrong number of ranges")
    checked = ntuple(ndims(A)) do d
        r = ranges[d]
        if r === nothing
            axes(A,d)
        elseif axes(r,1) == axes(A,d)
            r
        elseif length(r) == size(A,d)
            OffsetArray(r, axes(A,d))
        else
            error("wrong length of ranges")
        end
    end
    ndims(A) == 1 ? Ref(first(checked)) : checked
end
