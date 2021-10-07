#=

This is an experiment, with returning something very similar to a KeyedArray from axes(A,1).
The reason to do so is that things like similar(C, axes(A,1), axes(B,2)) could propagate keys.
However right now axes(A,1) !isa Base.OneTo results in lots of OffsetArrays...

=#

"""
    AxisKeys.KeyedUnitRange(Base.OneTo(3), ["a", "b", "c"])

This exists to store both `axes(parent(A), d)`, and `axiskeys(A, d)` together,
as one `AbstractUnitRange`, so that generic code which propagages `axes(A)`
will pass keys along.
"""
struct KeyedUnitRange{T,AT,KT} <: AbstractUnitRange{T}
    data::AT
    keys::KT
    function KeyedUnitRange(data::AT, keys::KT) where {AT<:AbstractUnitRange{T}, KT<:AbstractVector} where {T}
        new{T,AT,KT}(data, keys)
    end
end

Base.parent(A::KeyedUnitRange) = getfield(A, :data)
keyless(A::KeyedUnitRange) = parent(A)

for f in [:size, :length, :axes, :first, :last, :IndexStyle]
    @eval Base.$f(A::KeyedUnitRange) = $f(parent(A))
end

Base.getindex(A::KeyedUnitRange, ind::Integer) = getindex(parent(A), ind)

axiskeys(A::KeyedUnitRange) = tuple(getfield(A, :keys))
axiskeys(A::KeyedUnitRange, d::Integer) = d==1 ? getfield(A, :keys) : Base.OneTo(1)

haskeys(A::KeyedUnitRange) = true

# getkey(A::AbstractKeyedArray{<:Any,1}, key) = findfirst(isequal(key), axiskeys(A)[1])


# Use for KeyedArray, and for reconstruction of such.

function Base.axes(A::KeyedArray)
    ntuple(ndims(A)) do d
        KeyedUnitRange(axes(parent(A), d), axiskeys(A, d))
    end
end

Base.similar(A::AbstractArray, ::Type{T}, ax::Tuple{KeyedUnitRange}) where {T} = _similar(A, T, ax)
Base.similar(A::AbstractArray, ::Type{T}, ax::Tuple{AbstractUnitRange, KeyedUnitRange, Vararg{AbstractUnitRange}}) where {T} = _similar(A, T, ax)
Base.similar(A::AbstractArray, ::Type{T}, ax::Tuple{KeyedUnitRange, AbstractUnitRange, Vararg{AbstractUnitRange}}) where {T} = _similar(A, T, ax)
Base.similar(A::AbstractArray, ::Type{T}, ax::Tuple{KeyedUnitRange, KeyedUnitRange, Vararg{AbstractUnitRange}})  where {T} = _similar(A, T, ax)
function _similar(A, ::Type{T}, ax) where {T}
    data = similar(keyless(A), T, map(keyless, ax))
    new_keys = map(a -> keys_or_axes(a,1), ax)
    KeyedArray(data, new_keys)
end

Base.reshape(A::AbstractArray, ax::Tuple{KeyedUnitRange}) = _reshape(A, ax)
Base.reshape(A::AbstractArray, ax::Tuple{AbstractUnitRange, KeyedUnitRange, Vararg{AbstractUnitRange}}) = _reshape(A, ax)
Base.reshape(A::AbstractArray, ax::Tuple{KeyedUnitRange, AbstractUnitRange, Vararg{AbstractUnitRange}}) = _reshape(A, ax)
Base.reshape(A::AbstractArray, ax::Tuple{KeyedUnitRange, KeyedUnitRange, Vararg{AbstractUnitRange}}) = _reshape(A, ax)
function _reshape(A, ax)
    data = reshape(keyless(A), map(keyless, ax))
    new_keys = map(a -> keys_or_axes(a,1), ax)
    KeyedArray(data, new_keys)
end

# Pretty printing

KeyedUnion{T} = Union{KeyedArray{T}, KeyedUnitRange{T}}

using NamedDims

Base.summary(io::IO, x::KeyedUnion) = _summary(io, x)
Base.summary(io::IO, A::NamedDimsArray{L,T,N,<:KeyedUnion}) where {L,T,N} = _summary(io, A)
showtype(io::IO, ::KeyedUnitRange) = print(io, "KeyedUnitRange(...)")

function Base.show(io::IO, m::MIME"text/plain", x::KeyedUnitRange)
    summary(io, x)
    println(io, ":")
    keyed_print_matrix(io, x)
end

function Base.show(io::IO, x::KeyedUnitRange)
    print(io, "KeyedUnitRange(", keyless(x), ", ", axiskeys(x,1), ")")
end
