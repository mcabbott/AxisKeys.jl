#=
Largely copied from NamedDims:
https://github.com/invenia/NamedDims.jl/blob/master/src/broadcasting.jl
=#

using Base.Broadcast:
    Broadcasted, BroadcastStyle, DefaultArrayStyle, AbstractArrayStyle, Unknown

struct KeyedStyle{S <: BroadcastStyle} <: AbstractArrayStyle{Any} end
KeyedStyle(::S) where {S} = KeyedStyle{S}()
KeyedStyle(::S, ::Val{N}) where {S,N} = KeyedStyle(S(Val(N)))
KeyedStyle(::Val{N}) where {N} = KeyedStyle{DefaultArrayStyle{N}}()

function KeyedStyle(a::BroadcastStyle, b::BroadcastStyle)
    inner_style = BroadcastStyle(a, b)
    inner_style isa Unknown ? Unknown() : KeyedStyle(inner_style)
end

Base.BroadcastStyle(::Type{<:KeyedArray{T,N,AT}}) where {T,N,AT} =
    KeyedStyle{typeof(BroadcastStyle(AT))}()
Base.BroadcastStyle(::KeyedStyle{A}, ::KeyedStyle{B}) where {A, B} = KeyedStyle(A(), B())
Base.BroadcastStyle(::KeyedStyle{A}, b::B) where {A, B} = KeyedStyle(A(), b)
Base.BroadcastStyle(a::A, ::KeyedStyle{B}) where {A, B} = KeyedStyle(a, B())

using NamedDims: NamedDimsStyle
# this resolves in favour of KeyedArray(NamedDimsArray())
Base.BroadcastStyle(a::NamedDimsStyle, ::KeyedStyle{B}) where {B} = KeyedStyle(a, B())
Base.BroadcastStyle(::KeyedStyle{A}, b::NamedDimsStyle) where {A} = KeyedStyle(A(), b)

# Resolve ambiguities
# for all these cases, we define that we win to be the outer style regardless of order
for B in (
    :BroadcastStyle, :DefaultArrayStyle, :AbstractArrayStyle, :(Broadcast.Style{Tuple}),
)
    @eval function Base.BroadcastStyle(::KeyedStyle{A}, b::$B) where A
        return KeyedStyle(A(), b)
    end
    @eval function Base.BroadcastStyle(b::$B, ::KeyedStyle{A}) where A
        return KeyedStyle(b, A())
    end
end

function unwrap_broadcasted(bc::Broadcasted{KeyedStyle{S}}) where {S}
    inner_args = map(unwrap_broadcasted, bc.args)
    Broadcasted{S}(bc.f, inner_args)
end
unwrap_broadcasted(x) = x
unwrap_broadcasted(x::KeyedArray) = parent(x)

function Broadcast.copy(bc::Broadcasted{KeyedStyle{S}}) where {S}
    inner_bc = unwrap_broadcasted(bc)
    data = copy(inner_bc)
    R = broadcasted_keys(bc)
    KeyedArray(data, map(copy, R))
end

function Base.copyto!(dest::AbstractArray, bc::Broadcasted{KeyedStyle{S}}) where {S}
    inner_bc = unwrap_broadcasted(bc)
    data = copyto!(keyless(dest), inner_bc)
    R = unify_keys(keys_or_axes(dest), broadcasted_keys(bc))
    KeyedArray(data, R)
end

broadcasted_keys(bc::Broadcasted) = broadcasted_keys(bc.args...)
function broadcasted_keys(a, bs...)
    a_r = broadcasted_keys(a)
    b_r = broadcasted_keys(bs...)
    unify_longest(a_r, b_r)
end
broadcasted_keys(a::AbstractArray) = keys_or_axes(a)
broadcasted_keys(a) = tuple()

#===== Unification, also used by map, hcat, etc. =====#

function unify_longest(short::Tuple, long::Tuple)
    length(short) > length(long) && return unify_longest(long, short)
    overlap = unify_keys(short, ntuple(i -> long[i], length(short)))
    extra = ntuple(i -> long[i + length(short)], length(long) - length(short))
    return (overlap..., extra...)
end
unify_longest(x::Tuple) = x
unify_longest(x,y,zs...) = unify_longest(unify_longest(x,y), zs...)

unify_keys(left::Tuple, right::Tuple) = map(unify_one, left, right)
unify_keys(left::Tuple) = left
unify_keys(left, right, more...) = unify_keys(unify_keys(left, right), more...)

unifiable_keys(left::Tuple, right::Tuple) = map(who_wins, left, right) isa Tuple{Vararg{AbstractArray}}

function unify_one(x::AbstractArray, y::AbstractArray)
    out = who_wins(x,y)
    out === nothing && throw(ArgumentError("key vectors must agree; got $x != $y"))
    out
end
unify_one(x,y,zs...) = unify_one(unify_one(x,y), zs...)

"""
    who_wins(axisranges(A,1), axisranges(B,1))
    who_wins(r, s, t, ...)

For broadcasting, but also `map` etc, this compares individual key vectors
and returns the one to keep.
In general they must agree `==`, and the simpler type will be returned
(e.g. `Vector + UnitRange -> UnitRange`).

However default key vectors `Base.OneTo(n)` are regarded as wildcards.
They need not agree with anyone, and are always discarded in favour of other types.

If the keys disagree it returns `nothing`.
Call `unify_one()` to have an error instead.
"""
who_wins(x,y,zs...) = who_wins(who_wins(x,y), zs...)

who_wins(r::AbstractVector, s::AbstractVector) = r === s ? r : r == s ? r : nothing
who_wins(vec::AbstractVector, ran::AbstractRange) = vec == ran ? ran : nothing
who_wins(ran::AbstractRange, vec::AbstractVector) = vec == ran ? ran : nothing
who_wins(r::AbstractRange, s::AbstractRange) = r == s ? r : nothing

who_wins(arr::AbstractVector, ot::Base.OneTo) = arr
who_wins(ot::Base.OneTo, arr::AbstractVector) = arr
who_wins(ot::Base.OneTo, ot′::Base.OneTo) = ot # else ambiguous
who_wins(arr::AbstractRange, ot::Base.OneTo) = arr # also to solve ambiguity
who_wins(ot::Base.OneTo, arr::AbstractRange) = arr
