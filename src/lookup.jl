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
        inds_raw = map(findindex, args, axiskeys(A))
        inds = Base.to_indices(A, inds_raw)
        @boundscheck checkbounds(A, inds...)
        return @inbounds get_or_view(A, inds...)

    elseif length(args) > ndims(A) && all(args[ndims(A)+1:end] .== (:)) # trailing colons
        args_nd = args[1:ndims(A)]
        inds_raw = map(findindex, args_nd, axiskeys(A))
        inds = Base.to_indices(A, inds_raw)
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
    [findindex(x, r) for x in a]

findindex(f::Function, r::AbstractArray) = findall(f, r)

findindex(i::AbstractUnitRange{T}, r::AbstractUnitRange{T}) where {T} = findall(∈(i), r)

# Faster than Base.findall(==(i), 1:10) etc,
# but returning a range not an Array:

function findindex(eq::Base.Fix2{<:Union{typeof(==),typeof(isequal)},Int}, r::Base.OneTo{Int})
    1 <= eq.x <= r.stop ? (eq.x:eq.x) : (1:0)
end

function findindex(eq::Base.Fix2{<:Union{typeof(==),typeof(isequal)},Int}, r::AbstractUnitRange)
    val = 1 + Int(eq.x - first(r))
    first(r) <= eq.x <= last(r) ? (val:val) : (1:0)
end

# See also findrange.jl for findindex(<=(3), range) things.

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
        ds = findall(T -> argT.parameters[end] <: T, types)
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
