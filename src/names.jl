using NamedDims

# Abbreviations for things which have both names & ranges:

NdaRa{L,T,N} = NamedDimsArray{L,T,N,<:RangeArray}
RaNda{L,T,N} = RangeArray{T,N,<:NamedDimsArray{L}}

# Just make names get the names, and behave like size(A,d), axes(A,d) etc.

Base.names(A::RaNda{L}) where {L} = L
Base.names(A::RaNda{L,T,N}, d::Int) where {L,T,N} = d <= N ? L[d] : :_
Base.names(A::NamedDimsArray{L}) where {L} = L # 🏴‍☠️
Base.names(A::NamedDimsArray{L,T,N}, d::Int) where {L,T,N} = d <= N ? L[d] : :_ # 🏴‍☠️

Base.axes(A::RaNda{L}, s::Symbol) where {L} = axes(A, NamedDims.dim(L,s))
Base.size(A::RaNda{L,T,N}, s::Symbol) where {T,N,L} = size(A, NamedDims.dim(L,s))

# Extra complication to make wrappers commutative:

hasnames(A::RaNda) = true
hasnames(A::NamedDimsArray) = true
hasnames(A) = false

NamedDims.unname(A::RaNda) = RangeArray(unname(A.data), A.ranges)
rangeless(A::NdaRa{L}) where {L} = NamedDimsArray(A.data.data, L)

ranges(A::NdaRa) = ranges(parent(A))
ranges(A::NdaRa, d::Int) = ranges(parent(A), d)

ranges(A::NdaRa{L}, s::Symbol) where {L} = ranges(parent(A), NamedDims.dim(L,s))
ranges(A::RaNda{L}, s::Symbol) where {L} = ranges(A, NamedDims.dim(L,s))

hasranges(A::NdaRa) = true
hasranges(A::RangeArray) = true
hasranges(A) = false

ranges_or_axes(A) = hasranges(A) ? ranges(A) : axes(A)
ranges_or_axes(A, d) = hasranges(A) ? ranges(A, d) : axes(A, d)

# Re-constructors:

function RangeArray(A::NdaRa, r2::Tuple)
    r3 = unify_ranges(ranges(parent(A)), r2)
    RangeArray(rangeless(A), r3)
end

function NamedDims.NamedDimsArray(A::RaNda{L}, L2::Tuple) where {L}
    L3 = NamedDims.unify_names(L, L2)
    NamedDimsArray(NamedDims.unname(A), L3)
end

# getproperty: it's useful to say for `(i,t) in enumerate(A.time)` etc.
# This will make saying ".data" slow (by 30ns), fixed in NamedDims.jl#78

Base.propertynames(A::NdaRa{L}, private=false) where {L} =
    private ? (L..., fieldnames(typeof(A))...) : L
Base.propertynames(A::RaNda{L}, private=false) where {L} =
    private ? (L..., fieldnames(typeof(A))...) : L

Base.getproperty(A::NdaRa{L}, s::Symbol) where {L} =
    Base.sym_in(s, L) ? ranges(A, NamedDims.dim(L, s)) : getfield(A, s)
Base.getproperty(A::RaNda{L}, s::Symbol) where {L} =
    Base.sym_in(s, L) ? ranges(A, NamedDims.dim(L, s)) : getfield(A, s)
Base.getproperty(A::NamedDimsArray{L}, s::Symbol) where {L} =
    Base.sym_in(s, L) ? axes(A, NamedDims.dim(L, s)) : getfield(A, s) # 🏴‍☠️?

# Keyword indexing of RangeArray:

@inline @propagate_inbounds function Base.getindex(A::RangeArray; kw...)
    hasnames(A) || error("must have names!")
    inds = NamedDims.order_named_inds(Val(names(A)); kw...)
    getindex(A, inds...)
end

# Any NamedDimsArray + RangeArray combination is callable:

@inline @propagate_inbounds (A::NdaRa)(args...) = getkey(A, args...)

@inline @propagate_inbounds (A::RaNda)(;kw...) = getkey(A; kw...)
@inline @propagate_inbounds (A::NdaRa)(;kw...) = getkey(A; kw...)

@inline @propagate_inbounds function getkey(A; kw...)
    list = names(A)
    issubset(kw.itr, list) || error("some keywords not in list of names!")
    args = map(s -> Base.sym_in(s, kw.itr) ? getfield(kw.data, s) : Colon(), list)
    A(args...)
end

#=
# NamedTuple-makers.

"""
    namedranges(A)
    namedaxes(A)

Combines `names(A)` and either `ranges(A)` or `axes(A)` into a `NamedTuple`.
"""
namedranges(A::NdaRa{L}) where {L} = NamedTuple{L}(ranges(A))
namedranges(A::RaNda{L}) where {L} = NamedTuple{L}(ranges(A))
namedranges(A::NamedDimsArray{L}) where {L} = NamedTuple{L}(axes(A))

@doc @doc(namedranges)
namedaxes(A::NdaRa{L}) where {L} = NamedTuple{L}(axes(A))
namedaxes(A::RaNda{L}) where {L} = NamedTuple{L}(axes(A))
namedaxes(A::NamedDimsArray{L}) where {L} = NamedTuple{L}(axes(A))

=#
#=
using LazyStack

# decide on this function name, and register it
function LazyStack.maybe_add_names(A, a::NamedTuple)
    range_first = ntuple(d -> d==1 ? collect(keys(a)) : axes(A,d), ndims(A))
    name_first = ntuple(d -> d==1 ? :names : :_, ndims(A))
    rs = unify_ranges(ranges_or_axes(A), range_first)
    RangeArray(NamedDimsArray(rangeless(A), name_first), rs)
end

stack((a=1,b=2,c=3), (a=2,b=3,c=4))
stack(:new, [(a=1,b=2,c=3), (a=2,b=3,c=4)])
=#
