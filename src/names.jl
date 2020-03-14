using NamedDims

# Abbreviations for things which have both names & keys:

NdaKa{L,T,N} = NamedDimsArray{L,T,N,<:KeyedArray}
KaNda{L,T,N} = KeyedArray{T,N,<:NamedDimsArray{L}}
NdaKaVoM{L,T,N} = NamedDimsArray{L,T,N,<:KeyedVecOrMat}

# NamedDims now uses dimnames, which behaves like size(A,d), axes(A,d) etc.

NamedDims.dimnames(A::KaNda{L}) where {L} = L
NamedDims.dimnames(A::KaNda{L,T,N}, d::Int) where {L,T,N} = d <= N ? L[d] : :_

Base.axes(A::KaNda{L}, s::Symbol) where {L} = axes(A, NamedDims.dim(L,s))
Base.size(A::KaNda{L,T,N}, s::Symbol) where {T,N,L} = size(A, NamedDims.dim(L,s))

# Extra complication to make wrappers commutative:

hasnames(A::KaNda) = true
hasnames(A::NamedDimsArray) = true
hasnames(A) = false

NamedDims.unname(A::KaNda) = KeyedArray(unname(A.data), axiskeys(A))
keyless(A::NdaKa{L}) where {L} = NamedDimsArray(A.data.data, L)

axiskeys(A::NdaKa) = axiskeys(parent(A))
axiskeys(A::NdaKa, d::Int) = axiskeys(parent(A), d)

axiskeys(A::NdaKa{L}, s::Symbol) where {L} = axiskeys(parent(A), NamedDims.dim(L,s))
axiskeys(A::KaNda{L}, s::Symbol) where {L} = axiskeys(A, NamedDims.dim(L,s))

haskeys(A::NdaKa) = true
haskeys(A::KeyedArray) = true
haskeys(A) = false

keys_or_axes(A) = haskeys(A) ? axiskeys(A) : axes(A)
keys_or_axes(A, d) = haskeys(A) ? axiskeys(A, d) : axes(A, d)

# Re-constructors:

function KeyedArray(A::NdaKa, r2::Tuple)
    r3 = unify_keys(axiskeys(parent(A)), r2)
    KeyedArray(keyless(A), r3)
end

function NamedDims.NamedDimsArray(A::KaNda{L}, L2::Tuple) where {L}
    L3 = NamedDims.unify_names(L, L2)
    NamedDimsArray(NamedDims.unname(A), L3)
end

# getproperty: it's useful to say for `(i,t) in enumerate(A.time)` etc.
# This will make saying ".data" slow (by 30ns), fixed in NamedDims.jl#78

Base.propertynames(A::NdaKa{L}, private=false) where {L} =
    private ? (L..., fieldnames(typeof(A))...) : L
Base.propertynames(A::KaNda{L}, private=false) where {L} =
    private ? (L..., fieldnames(typeof(A))...) : L

Base.getproperty(A::NdaKa{L}, s::Symbol) where {L} =
    Base.sym_in(s, L) ? axiskeys(A, NamedDims.dim(L, s)) : getfield(A, s)
Base.getproperty(A::KaNda{L}, s::Symbol) where {L} =
    Base.sym_in(s, L) ? axiskeys(A, NamedDims.dim(L, s)) : getfield(A, s)
Base.getproperty(A::NamedDimsArray{L}, s::Symbol) where {L} =
    Base.sym_in(s, L) ? axes(A, NamedDims.dim(L, s)) : getfield(A, s) # 🏴‍☠️?

# Keyword indexing of KeyedArray:

@inline @propagate_inbounds function Base.getindex(A::KeyedArray; kw...)
    hasnames(A) || error("must have names!")
    inds = NamedDims.order_named_inds(Val(dimnames(A)); kw...)
    getindex(A, inds...)
end
@inline @propagate_inbounds function Base.view(A::KeyedArray; kw...)
    hasnames(A) || error("must have names!")
    inds = NamedDims.order_named_inds(Val(dimnames(A)); kw...)
    view(A, inds...)
end

# Any NamedDimsArray + KeyedArray combination is callable:

@inline @propagate_inbounds (A::NdaKa)(args...) = getkey(A, args...)

@inline @propagate_inbounds (A::KaNda)(;kw...) = getkey(A; kw...)
@inline @propagate_inbounds (A::NdaKa)(;kw...) = getkey(A; kw...)

@inline @propagate_inbounds function getkey(A; kw...)
    list = dimnames(A)
    issubset(kw.itr, list) || error("some keywords not in list of names!")
    args = map(s -> Base.sym_in(s, kw.itr) ? getfield(kw.data, s) : Colon(), list)
    A(args...)
end

#=
# NamedTuple-makers.

"""
    namedaxiskeys(A)
    namedaxes(A)

Combines `dimnames(A)` and either `axiskeys(A)` or `axes(A)` into a `NamedTuple`.
"""
namedaxiskeys(A::NdaKa{L}) where {L} = NamedTuple{L}(axiskeys(A))
namedaxiskeys(A::KaNda{L}) where {L} = NamedTuple{L}(axiskeys(A))
namedaxiskeys(A::NamedDimsArray{L}) where {L} = NamedTuple{L}(axes(A))

@doc @doc(namedranges)
namedaxes(A::NdaKa{L}) where {L} = NamedTuple{L}(axes(A))
namedaxes(A::KaNda{L}) where {L} = NamedTuple{L}(axes(A))
namedaxes(A::NamedDimsArray{L}) where {L} = NamedTuple{L}(axes(A))

=#
#=
using LazyStack

# decide on this function name, and register it
function LazyStack.maybe_add_names(A, a::NamedTuple)
    range_first = ntuple(d -> d==1 ? collect(keys(a)) : axes(A,d), ndims(A))
    name_first = ntuple(d -> d==1 ? :names : :_, ndims(A))
    rs = unify_keys(keys_or_axes(A), range_first)
    KeyedArray(NamedDimsArray(keyless(A), name_first), rs)
end

stack((a=1,b=2,c=3), (a=2,b=3,c=4))
stack(:new, [(a=1,b=2,c=3), (a=2,b=3,c=4)])
=#
