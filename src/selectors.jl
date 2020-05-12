
using InvertedIndices
# needs only Base.to_indices in struct.jl to work,
# plus this to work when used in round brackets:

findindex(not::InvertedIndex, r::AbstractVector) = Base.unalias(r, not)

using IntervalSets

findindex(s::Interval, r::AbstractVector) = findall(i -> i in s, r)

# For whether this can be efficient, see https://github.com/JuliaMath/IntervalSets.jl/issues/52

"""
    Near(val)
    Interval(lo, hi)

These selectors modify lookup using `axiskeys(A)`:
`B(time = Near(3))` matches one entry with minimum `abs2(t-3)` of named dimension `:time`.
`C("cat", Interval(10,20))` matches all entries with `10 <= iter <= 20`).

`Interval` is from IntervalSets.jl, and using that you may also write `lo .. hi`,
as well as `mid ± δ`.

    ==(val)
    <(val)

Any functions can be used similarly, like C(!=("dog"), <=(33)).
They ultimately call `findall(==(val), axiskeys(A,d))`.

Functions of type `Base.Fix2`, and `Selector`s, also allow a dimension
to be chosen by type: `A(<=(3.1))` will work provided that only one of
`map(eltype, axiskeys(A))` matches `typeof(3.1)`.
"""
abstract type Selector{T} end

Base.eltype(::Type{<:Selector{T}}) where {T} = T

@doc @doc(Selector)
struct Near{T} <: Selector{T}
    val::T
end

Base.show(io::IO, s::Near) = print(io, "Near(",s.val,")")
Base.show(io::IO, ::MIME"text/plain", s::Near{T}) where {T} =
    print(io, "Near(",s.val,") ::Selector{",T,"}")

findindex(sel::Near, range::AbstractArray) = argmin(map(x -> abs(x-sel.val), range))

function findindex(sel::Near, range::AbstractRange)
    iplus = searchsortedfirst(range, sel.val)
    # "index of the first value in a greater than or equal to x"
    if abs(range[iplus]-sel.val) < abs(range[iplus-1]-sel.val)
        return iplus
    else
        return iplus-1
    end
end

_index_key_doc = """
    Index[i]

This exists to let you mix in square-bracket indexing,
like `A(:b, Near(3.14), Index[4:5], "f")`.
You may also write `Index[end]`, although not yet `Index[end-2]`.

    Key(val)

This exists to perform lookup inside indexing, to allow
`A[Key(:b), Near(3.14), 4:5, Key("f")]`.

Writing `Key(isequal(:b))` is equivalent to just `isequal(:b)`, and will find all matches,
while `Key(:b)` finds only the first (and drops the dimension).
"""

@doc _index_key_doc
struct Index{T} <: Selector{T}
    ind::T
end

Base.show(io::IO, s::Index{T}) where {T} = print(io, "Index[",s.ind, "]")

Base.getindex(::Type{Index}, i) = Index(i)

findindex(sel::Index, range::AbstractArray) = sel.ind

struct LastIndex <: Selector{Int} end

Base.lastindex(::Type{Index}) = LastIndex()

Index(::LastIndex) = LastIndex()

findindex(sel::LastIndex, range::AbstractArray) = lastindex(range)

if VERSION >= v"1.4" # same thing for Index[begin]
    struct FirstIndex <: Selector{Int} end
    Base.firstindex(::Type{Index}) = FirstIndex()
    Index(::FirstIndex) = FirstIndex()
    findindex(sel::FirstIndex, range::AbstractArray) = firstindex(range)
end

@doc _index_key_doc
struct Key{T} <: Selector{T}
    val::T
end

Base.show(io::IO, s::Key) = print(io, "Key(",s.val,")")
Base.show(io::IO, ::MIME"text/plain", s::Key{T}) where {T} =
    print(io, "Key(",s.val,") ::Selector{",T,"}")

findindex(sel::Key, range::AbstractArray) = findindex(sel.val, range)

"""
    Base.to_indices(A, axes, inds)
    select_to_indices(A, axes, inds)

This recursively peels off the indices & axes, `select_to_indices` gets called
when the first remaining index is a Selector, Interval, or a Function.
"""
@inline function select_to_indices(A, axes, inds)
    d = ndims(A) - length(axes) + 1 # infer how many have been peeled off?
    i = findindex(first(inds), axiskeys(A, d))
    (i, Base.to_indices(A, Base.tail(axes), Base.tail(inds))...)
end

@inline Base.to_indices(A, ax, inds::Tuple{Selector, Vararg}) = select_to_indices(A, ax, inds)

# For the rest I don't own these types... which then creates ambiguities...
@inline Base.to_indices(A::Union{KeyedArray,NdaKa}, ax, inds::Tuple{IntervalSets.Domain, Vararg}) =
    select_to_indices(A, ax, inds)
@inline Base.to_indices(A::Union{KeyedArray,NdaKa}, ax, inds::Tuple{Function, Vararg}) =
    select_to_indices(A, ax, inds)

using Base: to_indices, tail, _maybetail, uncolon

@inline Base.to_indices(A::Union{KeyedArray,NdaKa}, inds, I::Tuple{Colon, Vararg{Any}}) =
    (uncolon(inds, I), to_indices(A, _maybetail(inds), tail(I))...)


#=

V = KeyedArray(rand(5), 'a':'e')
V('a')
V[Key('a')]

W = KeyedArray(rand(3,5), row=10:10:30, col='a':'e')
W = NamedDimsArray(rand(3,5), row=10:10:30, col='a':'e')
W('a')
W[:, Key('a')]
W[col=Key('a')]

W[row=Interval(1,25)]
W[row=Near(23)]


B = wrapdims(rand(10,3,2), animal='🐶':'🐷', letter=["a","b","c"], number=6:7)
newaxis = [CartesianIndex{0}()]

B[rand(10) .> 0.7, ==("b"), :, newaxis]

B[==('🐶'), CartesianIndex(1,1), 1,1,1]


=#

#=

Base.@propagate_inbounds function Base.getindex(a::NamedDimsArray, inds_or_keys::Vararg{Union{
    Integer, Function, Selector, IntervalSets.Domain
    }})
    # Some nonscalar case, will return an array, so need to give that names.
    inds = Base.to_indices(a, inds_or_keys)
    data = Base.getindex(parent(a), inds...)
    L = NamedDims.remaining_dimnames_from_indexing(dimnames(a), inds)
    return NamedDimsArray{L}(data)
end
=#
