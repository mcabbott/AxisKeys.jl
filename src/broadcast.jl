#=
Inspiration:
https://github.com/invenia/NamedDims.jl/blob/master/src/broadcasting.jl
https://github.com/Tokazama/AbstractIndices.jl/blob/master/src/broadcasting.jl
=#

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














function unify_longest(short, long)
    length(short) > length(short) && return unify_longest(long, short)
    overlap = unify_shortest(short, long)
    extra = ntuple(i -> long[i + length(short)], length(long) - length(short))
    return (overlap..., extra...)
end

unify_shortest(left, right) = map(who_wins, left, right)

# Base.OneTo always loses:
who_wins(r::AbstractArray, s::Base.OneTo) = r
who_wins(r::Base.OneTo, s::AbstractArray) = s
# Ranges lose to vectors:
who_wins(r::AbstractArray, s::AbstractRange) = r
who_wins(r::AbstractRange, s::AbstractArray) = s
# Otherwise just pick the first:
who_wins(r, s) = r
