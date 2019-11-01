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
    overlap = unify_shortest(short, long)
    extra = ntuple(i -> long[i + length(short)], length(long) - length(short))
    return (overlap..., extra...)
end
unify_longest(x) = x
unify_longest(x,y,zs...) = unify_longest(unify_longest(x,y), zs...)

unify_shortest(left, right) = map(who_wins, left, right)
unify_shortest(left) = left
unify_shortest(left, right, more...) = unify_shortest(unify_shortest(left, right), more...)

# Base.OneTo is always discarded:
who_wins(arr::AbstractVector, ot::Base.OneTo) = arr
who_wins(ot::Base.OneTo, arr::AbstractVector) = arr
who_wins(ot::Base.OneTo, ot′::Base.OneTo) = ot # else ambiguous
# Other ranges must agree, just keep first:
who_wins(r::AbstractRange, s::AbstractRange) = r == s ? r : error("ranges must agree")
# Ranges are kept over vectors:
who_wins(vec::AbstractVector, ran::AbstractRange) = vec == ran ? ran : error("ranges must agree")
who_wins(ran::AbstractRange, vec::AbstractVector) = vec == ran ? ran : error("ranges must agree")
# Otherwise just pick the first:
who_wins(r, s) = r == s ? r : error("ranges must agree")
# And, given more than two, work pairwise:
who_wins(x,y,zs...) = who_wins(who_wins(x,y), zs...)
