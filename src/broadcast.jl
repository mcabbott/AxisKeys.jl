#=
Largely copied from NamedDims:
https://github.com/invenia/NamedDims.jl/blob/master/src/broadcasting.jl
=#

using Base.Broadcast:
    Broadcasted, BroadcastStyle, DefaultArrayStyle, AbstractArrayStyle, Unknown

struct RangeStyle{S <: BroadcastStyle} <: AbstractArrayStyle{Any} end
RangeStyle(::S) where {S} = RangeStyle{S}()
RangeStyle(::S, ::Val{N}) where {S,N} = RangeStyle(S(Val(N)))
RangeStyle(::Val{N}) where {N} = RangeStyle{DefaultArrayStyle{N}}()

function RangeStyle(a::BroadcastStyle, b::BroadcastStyle)
    inner_style = BroadcastStyle(a, b)
    inner_style isa Unknown ? Unknown() : RangeStyle(inner_style)
end

Base.BroadcastStyle(::Type{<:RangeArray{T,N,AT}}) where {T,N,AT} =
    RangeStyle{typeof(BroadcastStyle(AT))}()
Base.BroadcastStyle(::RangeStyle{A}, ::RangeStyle{B}) where {A, B} = RangeStyle(A(), B())
Base.BroadcastStyle(::RangeStyle{A}, b::B) where {A, B} = RangeStyle(A(), b)
Base.BroadcastStyle(a::A, ::RangeStyle{B}) where {A, B} = RangeStyle(a, B())
Base.BroadcastStyle(::RangeStyle{A}, b::DefaultArrayStyle) where {A} = RangeStyle(A(), b)
Base.BroadcastStyle(a::AbstractArrayStyle{M}, ::RangeStyle{B}) where {B,M} = RangeStyle(a, B())

using NamedDims: NamedDimsStyle
# this resolves in favour of RangeArray(NamedDimsArray())
Base.BroadcastStyle(a::NamedDimsStyle, ::RangeStyle{B}) where {B} = RangeStyle(a, B())
Base.BroadcastStyle(::RangeStyle{A}, b::NamedDimsStyle) where {A} = RangeStyle(A(), b)

function unwrap_broadcasted(bc::Broadcasted{RangeStyle{S}}) where {S}
    inner_args = map(unwrap_broadcasted, bc.args)
    Broadcasted{S}(bc.f, inner_args)
end
unwrap_broadcasted(x) = x
unwrap_broadcasted(x::RangeArray) = parent(x)

function Broadcast.copy(bc::Broadcasted{RangeStyle{S}}) where {S}
    inner_bc = unwrap_broadcasted(bc)
    data = copy(inner_bc)
    R = broadcasted_ranges(bc)
    RangeArray(data, map(copy, R))
end

function Base.copyto!(dest::AbstractArray, bc::Broadcasted{RangeStyle{S}}) where {S}
    inner_bc = unwrap_broadcasted(bc)
    data = copyto!(rangeless(dest), inner_bc)
    R = unify_ranges(ranges_or_axes(dest), broadcasted_ranges(bc))
    RangeArray(data, R)
end

broadcasted_ranges(bc::Broadcasted) = broadcasted_ranges(bc.args...)
function broadcasted_ranges(a, bs...)
    a_r = broadcasted_ranges(a)
    b_r = broadcasted_ranges(bs...)
    unify_longest(a_r, b_r)
end
broadcasted_ranges(a::AbstractArray) = ranges_or_axes(a)
broadcasted_ranges(a) = tuple()

#===== Unification, also used by map, hcat, etc. =====#

function unify_longest(short::Tuple, long::Tuple)
    length(short) > length(long) && return unify_longest(long, short)
    overlap = unify_ranges(short, ntuple(i -> long[i], length(short)))
    extra = ntuple(i -> long[i + length(short)], length(long) - length(short))
    return (overlap..., extra...)
end
unify_longest(x::Tuple) = x
unify_longest(x,y,zs...) = unify_longest(unify_longest(x,y), zs...)

unify_ranges(left::Tuple, right::Tuple) = map(unify_one, left, right)
unify_ranges(left::Tuple) = left
unify_ranges(left, right, more...) = unify_ranges(unify_ranges(left, right), more...)

unifiable_ranges(left::Tuple, right::Tuple) = map(who_wins, left, right) isa Tuple{Vararg{AbstractArray}}

function unify_one(x::AbstractArray, y::AbstractArray)
    # length(x) == length(y) || throw(DimensionMismatch("ranges must have the same length!"))
    out = who_wins(x,y)
    out === nothing && throw(ArgumentError("ranges must agree; got $x != $y"))
    out
end
unify_one(x,y,zs...) = unify_one(unify_one(x,y), zs...)

"""
    who_wins(range(A,1), range(B,1))
    who_wins(r, s, t, ...)

For broadcasting, but also `map` etc, this compares individual ranges
and returns the one to keep.
In general they must agree `==`, and the simpler type will be returned
(e.g. `Vector + UnitRange -> UnitRange`).

However default ranges `Base.OneTo(n)` are regarded as wildcards.
They need not agree with anyone, and are always discarded in favour of other types.

If the ranges disagree it returns `nothing`.
Call `unify_one()` to have an error instead.
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
