#=
Inspiration:
https://github.com/invenia/NamedDims.jl/blob/master/src/broadcasting.jl
https://github.com/Tokazama/AbstractIndices.jl/blob/master/src/broadcasting.jl
=#

#=
using Base.Broadcast

struct RangeStyle{S <: BroadcastStyle} <: AbstractArrayStyle{Any} end
RangeStyle(::S) where {S} = RangeStyle{S}()
RangeStyle(::S, ::Val{N}) where {S,N} = RangeStyle(S(Val(N)))
RangeStyle(::Val{N}) where N = RangeStyle{DefaultArrayStyle{N}}()

function RangeStyle(a::BroadcastStyle, b::BroadcastStyle)
    inner_style = BroadcastStyle(a, b)
    if inner_style isa Unknown
        return Unknown()
    else
        return RangeStyle(inner_style)
    end
end

Base.BroadcastStyle(::Type{<:RangeArray{T,N,AT}}) where {T,N,AT} =
    RangeStyle{typeof(BroadcastStyle(AT))}()

Base.BroadcastStyle(::RangeStyle{A}, ::RangeStyle{B}) where {A, B} = (A(), B())
Base.BroadcastStyle(::RangeStyle{A}, b::B) where {A, B} = RangeStyle(A(), b)
Base.BroadcastStyle(a::A, ::RangeStyle{B}) where {A, B} = RangeStyle(a, B())
Base.BroadcastStyle(::RangeStyle{A}, b::DefaultArrayStyle) where {A} = RangeStyle(A(), b)
Base.BroadcastStyle(a::AbstractArrayStyle{M}, ::RangeStyle{B}) where {B,M} = RangeStyle(a, B())

# Broadcast.copy(bc::Broadcasted{BroadcastIndexStyle{S}}) where S =
#     asindex(copy(unwrap_broadcasted(bc)))


=#












function unify_longest(short, long)
    length(short) > length(short) && return unify_longest(long, short)
    overlap = unify_ranges(short, long)
    extra = ntuple(i -> long[i + length(short)], length(long) - length(short))
    return (overlap..., extra...)
end
unify_longest(x) = x
unify_longest(x,y,zs...) = unify_longest(unify_longest(x,y), zs...)

function unify_ranges(left, right)
    out = map(who_wins, left, right)
    out isa Tuple{Vararg{AbstractArray}} || error("ranges must agree")
    out
end
unify_ranges(left) = left
unify_ranges(left, right, more...) = unify_ranges(unify_ranges(left, right), more...)

unifiable_ranges(left, right) = map(who_wins, left, right) isa Tuple{Vararg{AbstractArray}}

"""
    who_wins(range(A,1), range(B,1))
    who_wins(r, s, t, ...)

For broadcasting, but also `map` etc, this compares individual ranges & returns the final one.
In general they must agree `==`, and the simpeler type will be returned
(e.g. `Vector + UnitRange -> UnitRange`).

However default ranges `Base.OneTo(n)` are regarded as wildcards.
They need not agree with anyone, and are always discarded in favour of other types.
"""
who_wins(x,y,zs...) = who_wins(who_wins(x,y), zs...)

who_wins(r::AbstractVector, s::AbstractVector) = r == s ? r : nothing
who_wins(vec::AbstractVector, ran::AbstractRange) = vec == ran ? ran : nothing
who_wins(ran::AbstractRange, vec::AbstractVector) = vec == ran ? ran : nothing
who_wins(r::AbstractRange, s::AbstractRange) = r == s ? r : nothing

who_wins(arr::AbstractVector, ot::Base.OneTo) = arr
who_wins(ot::Base.OneTo, arr::AbstractVector) = arr
who_wins(ot::Base.OneTo, ot′::Base.OneTo) = ot # else ambiguous
who_wins(arr::AbstractRange, ot::Base.OneTo) = arr # also to solve ambiguity
who_wins(ot::Base.OneTo, arr::AbstractRange) = arr
