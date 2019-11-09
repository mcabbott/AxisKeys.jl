using Base: @propagate_inbounds, OneTo, RefValue

struct RangeArray{T,N,AT,RT} <: AbstractArray{T,N}
    data::AT
    ranges::RT
end

const RangeVector{T,AT,RT} = RangeArray{T,1,AT,RT}
const RangeMatrix{T,AT,RT} = RangeArray{T,2,AT,RT}
const RangeVecOrMat{T,AT,RT} = Union{RangeVector{T,AT,RT}, RangeMatrix{T,AT,RT}}

function RangeArray(data::AbstractArray{T,N},
            ranges::Union{Tuple,RefValue} = axes(data)) where {T,N}

    length(ranges) == N || throw(ArgumentError(
        "wrong number of ranges, got $(length(ranges)) with ndims(A) == $N"))
    all(r -> r isa AbstractVector, ranges) || throw(ArgumentError(
        "ranges must all be AbstractVectors"))

    final = (N==1 && ranges isa Tuple) ? Ref(first(ranges)) : ranges
    RangeArray{T, N, typeof(data), typeof(final)}(data, final)
end

# RangeArray(data::AbstractVector, ref::RefValue{<:AbstractVector}) =
#     RangeArray{eltype(data), 1, typeof(data), typeof(ref)}(data, ref)
# RangeArray(data::AbstractVector, arr::AbstractVector) =
#     RangeArray{eltype(data), 1, typeof(data), typeof(Ref(arr))}(data, Ref(arr))

function RangeArray(A::RangeArray, r2::Tuple)
    r3 = unify_ranges(ranges(A), r2)
    RangeArray(parent(A), r3)
end

Base.size(x::RangeArray) = size(parent(x))

Base.axes(x::RangeArray) = axes(parent(x))

Base.parent(x::RangeArray) = getfield(x, :data)
rangeless(x::RangeArray) = parent(x)
rangeless(x) = x

ranges(x::RangeArray) = getfield(x, :ranges)
ranges(x::RangeVector) = tuple(getindex(getfield(x, :ranges)))
# avoiding Tuple(Ref()) as it's slow, https://github.com/JuliaLang/julia/pull/33674
ranges(x::RangeArray, d::Int) = d<=ndims(x) ? getindex(ranges(x), d) : OneTo(1)
ranges(x::RangeVector, d::Int) = d==1 ? getindex(getfield(x, :ranges)) : OneTo(1)

Base.IndexStyle(A::RangeArray) = IndexStyle(parent(A))
Base.eachindex(A::RangeArray) = eachindex(parent(A))

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
        d = guessdim(arg, ranges(A))
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

"""
    guessdim(key, ranges)

When you call `A(key)` for `ndims(A) > 1`, this returns which `d` you meant,
if unambigous, by comparing types & gradually widening
"""
@generated guessdim(arg, tup) = _guessdim(arg, map(eltype, Tuple(tup.parameters)))

function _guessdim(argT, types, subtypes=())
    types == subtypes && error("key of type $arT doesn't match any dimensions")

    # First look for direct match
    ds = findall(T -> argT <: T, types)

    if length(ds) == 1
        return first(ds)
    elseif length(ds) >= 2
        error("key of type $argT is ambiguous, matches dimensions $(Tuple(ds))")
    end

    # If no direct match, look for a container whose eltype matches:
    if argT <: Selector || argT <: AbstractArray || argT <: Interval
        ds = findall(T -> eltype(argT) <: T, types)
    elseif argT <: Base.Fix2 # Base.Fix2{typeof(==),Int64}
        ds = findall(T -> argT.parameters[2] <: T, types)
    end

    if length(ds) == 1
        return first(ds)
    elseif length(ds) >= 2
        error("key of type $argT is ambiguous, matches dimensions $(Tuple(ds))")
    end

    # Otherwise, widen the range types and try again.
    # This will recurse until types stop changing.
    supers = map(T -> supertype(T) == Any ? T : supertype(T), types)
    return _guessdim(argT, supers, types)
end

"""
    findindex(key, range)

This is usually `findfirst(isequal(key), range)`, and will error if it finds `nothing`.
But it also understands `findindex(:, range) = (:)`,
and `findindex(array, range) = vcat((findindex(x, range) for x in array)...)`.

It also understands functions `findindex(<(4), range) = findall(x -> x<4, range)`,
and selectors like `Nearest(key)` and `Interval(lo,hi)`.
"""
@inline function findindex(a, r::AbstractArray)
    i = findfirst(isequal(a), r)
    i === nothing && error("could not find key $a in range $r")
    i
end

findindex(a::Colon, r::AbstractArray) = Colon()

findindex(a::Union{AbstractArray, Base.Generator}, r::AbstractArray) =
    reduce(vcat, [findindex(x, r) for x in a])

findindex(f::Function, r::AbstractArray) = findall(f, r)

# It's possible this should be a method of to_indices or one of its friends?
# https://docs.julialang.org/en/v1/base/arrays/#Base.to_indices
