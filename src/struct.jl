using Base: @propagate_inbounds, OneTo, RefValue

using Compat # 2.0 hasfield + 3.1 filter

struct KeyedArray{T,N,AT,KT} <: AbstractArray{T,N}
    data::AT
    keys::KT
end

const KeyedVector{T,AT,RT} = KeyedArray{T,1,AT,RT}
const KeyedMatrix{T,AT,RT} = KeyedArray{T,2,AT,RT}
const KeyedVecOrMat{T,AT,RT} = Union{KeyedVector{T,AT,RT}, KeyedMatrix{T,AT,RT}}

function KeyedArray(data::AbstractArray{T,N},
            keys::Union{Tuple,RefValue}) where {T,N}
    _type_checks(data, keys) # pulled out to reduce allocations
    final = (N==1 && keys isa Tuple) ? Ref(first(keys)) : keys
    KeyedArray{T, N, typeof(data), typeof(final)}(data, final)
end

function _type_checks(data, keys::Tuple)
    length(keys) == ndims(data) || throw(ArgumentError(
        "wrong number of key vectors, got $(length(keys)) with ndims(A) == $(ndims(data))"))
    keys isa Tuple{Vararg{AbstractVector}} || throw(ArgumentError(
        "key vectors must all be AbstractVectors"))
end
function _type_checks(data, keys::Ref)
    ndims(data) == 1 || throw(ArgumentError(
        "wrong number of key vectors, got 1 with ndims(A) == $(ndims(data))"))
    keys isa RefValue{<:AbstractArray} || throw(ArgumentError(
        "key vector must be an AbstractVector"))
end

KeyedArray(data::AbstractVector, arr::AbstractVector) =
    KeyedArray{eltype(data), 1, typeof(data), typeof(Ref(arr))}(data, Ref(arr))

function KeyedArray(A::KeyedArray, r2::Tuple)
    r3 = unify_keys(axiskeys(A), r2)
    KeyedArray(parent(A), r3)
end
KeyedArray(data::KeyedVector, arr::AbstractVector) = KeyedArray(data, (arr,))

Base.size(x::KeyedArray) = size(parent(x))

Base.axes(x::KeyedArray) = axes(parent(x))

Base.parent(x::KeyedArray) = getfield(x, :data)
keyless(x::KeyedArray) = parent(x)
keyless(x) = x

axiskeys(x::KeyedArray) = getfield(x, :keys)
axiskeys(x::KeyedVector) = tuple(getindex(getfield(x, :keys)))
# avoiding Tuple(Ref()) as it's slow, https://github.com/JuliaLang/julia/pull/33674
axiskeys(x::KeyedArray, d::Int) = d<=ndims(x) ? getindex(axiskeys(x), d) : OneTo(1)
axiskeys(x::KeyedVector, d::Int) = d==1 ? getindex(getfield(x, :keys)) : OneTo(1)

Base.IndexStyle(A::KeyedArray) = IndexStyle(parent(A))

Base.eachindex(A::KeyedArray) = eachindex(parent(A))

Base.keys(A::KeyedArray) = error("Base.keys(::KeyedArray) not defined, please open an issue if this happens unexpectedly.")

for (bget, rget, cpy) in [(:getindex, :keys_getindex, :copy), (:view, :keys_view, :identity)]
    @eval begin

        @inline function Base.$bget(A::KeyedArray, I::Integer...)
            @boundscheck checkbounds(parent(A), I...)
            @inbounds Base.$bget(parent(A), I...)
        end

        @inline function Base.$bget(A::KeyedArray, I::Union{Colon, CartesianIndex})
            @boundscheck checkbounds(parent(A), I)
            @inbounds Base.$bget(parent(A), I)
        end

        @inline @propagate_inbounds function Base.$bget(A::KeyedArray, I...)
            @boundscheck checkbounds(parent(A), I...)
            data = @inbounds Base.$bget(parent(A), I...)

            @boundscheck map(checkbounds, axiskeys(A), I)
            new_keys = $rget(axiskeys(A), I)

            new_keys isa Tuple{} ? data : KeyedArray(data, new_keys)
        end

        @inline function $rget(keys, inds)
            got = map(keys, inds) do r,i
                i isa Integer       && return nothing
                i isa Colon         && return $cpy(r)        # avoids view([1,2,3], :)
                r isa AbstractRange && return getindex(r,i)  # don't make views of 1:10
                return @inbounds $bget(r,i)
            end
            filter(r -> r isa AbstractArray, got)
        end

    end
end

@inline function Base.setindex!(A::KeyedArray, val, I...)
    @boundscheck checkbounds(A, I...)
    @inbounds setindex!(parent(A), val, I...)
    val
end

@inline function Base.Broadcast.dotview(A::KeyedArray, I...)
    @boundscheck checkbounds(A, I...)
    @inbounds Base.dotview(parent(A), I...)
end

"""
    (A::KeyedArray)("a", 2.0, :γ) == A[1, 2, 3]
    A(:γ) == view(A, :, :, 3)

`KeyedArray`s are callable, and this behaves much like indexing,
except that it searches for the given keys in `axiskeys(A)`,
instead of `axes(A)` for indices.

A single key may be used to indicate a slice, provided that its type
only matches the eltype of one `axiskeys(A,d)`.
You can also slice explicitly with `A("a", :, :)`, both of these return a `view`.

An extra trailing colon (when all other indices are fixed) will return
a zero-dimensional `view`. This allows setting one value by
writing `A("a", 2.0, :γ, :) .= 100`.

Also accepts functions like `A(<=(2.0))` and selectors,
see `Nearest` and `Index`.
"""
@inline @propagate_inbounds (A::KeyedArray)(args...) = getkey(A, args...)

@inline function getkey(A, args...)
    if length(args) == ndims(A)
        inds = map(findindex, args, axiskeys(A))
        @boundscheck checkbounds(A, inds...)
        return @inbounds get_or_view(A, inds...)

    elseif length(args) > ndims(A) && all(args[ndims(A)+1:end] .== (:)) # trailing colons
        args_nd = args[1:ndims(A)]
        inds = map(findindex, args_nd, axiskeys(A))
        @boundscheck checkbounds(A, inds...)
        if inds isa NTuple{<:Any, Int}
            return @inbounds view(keyless(A), inds...) # zero-dim view of underlying
        else
            return @inbounds get_or_view(A, inds...)
        end

    elseif length(args)==1
        arg = first(args)
        d = inferdim(arg, axiskeys(A))
        i = findindex(arg, axiskeys(A,d))
        inds = ntuple(n -> n==d ? i : (:), ndims(A))
        @boundscheck checkbounds(A, inds...)
        return @inbounds view(A, inds...)

    end

    if length(args) != ndims(A)
        throw(ArgumentError(string("wrong number of keys: got ", length(args),
            " arguments, expected ndims(A) = ", ndims(A)," and perhaps a trailing colon.")))
    else
        throw(ArgumentError("can't understand what to do with $args, sorry"))
    end
end

@propagate_inbounds get_or_view(A, inds::Integer...) = getindex(A, inds...)
@propagate_inbounds get_or_view(A, inds...) = view(A, inds...)

@propagate_inbounds function setkey!(A, val, args...)
    length(args) == ndims(A) || error("wrong number of keys")
    inds = map((v,r) -> findindex(v,r), args, axiskeys(A))
    setindex!(A, val, inds...)
end

"""
    inferdim(key, axiskeys::Tuple)

When you call `A(key)` for `ndims(A) > 1`, this returns which `d` you meant,
if unambigous, by comparing types & gradually widening.
"""
@generated inferdim(arg, tup) = _inferdim(arg, map(eltype, Tuple(tup.parameters)))

function _inferdim(argT, types, subtypes=())
    types == subtypes && throw(ArgumentError("key of type $argT doesn't match any dimensions"))

    # First look for direct match
    ds = findall(T -> argT <: T, types)

    if length(ds) == 1
        return first(ds)
    elseif length(ds) >= 2
        throw(ArgumentError("key of type $argT is ambiguous, matches dimensions $(Tuple(ds))"))
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
        throw(ArgumentError("key of type $argT is ambiguous, matches dimensions $(Tuple(ds))"))
    end

    # Otherwise, widen the key types and try again.
    # This will recurse until types stop changing.
    supers = map(T -> supertype(T) == Any ? T : supertype(T), types)
    return _inferdim(argT, supers, types)
end

"""
    findindex(key, vec)

This is usually `findfirst(isequal(key), vec)`, and will error if it finds `nothing`.
But it also understands `findindex(:, vec) = (:)`,
and `findindex(array, vec) = vcat((findindex(x, vec) for x in array)...)`.

It also understands functions `findindex(<(4), vec) = findall(x -> x<4, vec)`,
and selectors like `Nearest(key)` and `Interval(lo,hi)`.
"""
@inline function findindex(a, r::AbstractArray)
    i = findfirst(isequal(a), r)
    i === nothing && throw(ArgumentError("could not find key $(repr(a)) in vector $r"))
    i
end

findindex(a::Colon, r::AbstractArray) = Colon()

findindex(a::Union{AbstractArray, Base.Generator}, r::AbstractArray) =
    reduce(vcat, [findindex(x, r) for x in a])

findindex(f::Function, r::AbstractArray) = findall(f, r)

# It's possible this should be a method of to_indices or one of its friends?
# https://docs.julialang.org/en/v1/base/arrays/#Base.to_indices
