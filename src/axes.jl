#=

This is an experiment, with returning something very similar to a KeyedArray from axes(A).
The reason to do so is that things like similar(C, axes(A,1), axes(B,2)) could propagate keys.
However right now axes(A,1) !isa Base.OneTo results in lots of OffsetArrays...

=#

struct KeyedUnitRange{T,AT,KT} <: AbstractUnitRange{T}
    data::AT
    keys::KT
    function KeyedUnitRange(data::AT, keys::KT) where {AT<:AbstractUnitRange{T}, KT<:AbstractVector} where {T}
        new{T,AT,KT}(data, keys)
    end
end

Base.parent(A::KeyedUnitRange) = getfield(A, :data)
keyless(A::KeyedUnitRange) = parent(A)

for f in [:size, :first, :last, :IndexStyle]
    @eval Base.$f(A::KeyedUnitRange) = $f(parent(A))
end

Base.getindex(A::KeyedUnitRange, inds::Integer) = getindex(parent(A), inds)

axiskeys(A::KeyedUnitRange) = tuple(getfield(A, :keys))
axiskeys(A::KeyedUnitRange, d::Integer) = d==1 ? getfield(A, :keys) : Base.OneTo(1)


# getkey(A::AbstractKeyedArray{<:Any,1}, key) = findfirst(isequal(key), axiskeys(A)[1])

function Base.axes(A::KeyedArray)
    ntuple(ndims(A)) do d
        KeyedUnitRange(axes(parent(A),d), axiskeys(A, d))
    end
end

KeyedUnion{T} = Union{KeyedArray{T}, KeyedUnitRange{T}}

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
