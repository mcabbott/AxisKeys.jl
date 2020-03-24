
using InvertedIndices # needs only Base.to_indices in struct.jl to work

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

findindex(sel::Near, range::AbstractArray) = argmin(map(x -> abs2(x-sel.val), range))

_index_key_doc = """
    Index[i]

This exists to let you mix in square-bracket indexing,
like `A(:b, Near(3.14), Index[4:5], "f")`.
You may also write `Index[end]`, although not yet `Index[end-2]`.

    Key(val)

This exists to perform lookup inside indexing, to allow
`A[Key(:b), Near(3.14), 4:5, Key("f")]`
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

function selector_indices(A, tup)
    length(tup) == ndims(A) || error("wrong number... maybe?")
    ntuple(ndims(A)) do d
        arg = tup[d]
        if arg isa Selector || arg isa Function || arg isa IntervalSets.AbstractInterval
            findindex(arg, axiskeys(A, d))
        else
            arg # Base.to_index(A, arg)
        end
    end
end

Base.to_indices(A::KeyedArray, tup::Tuple) = Base.to_indices(parent(A), selector_indices(A, tup))
Base.to_indices(A::NdaKa, tup::Tuple) = Base.to_indices(parent(parent(A)), selector_indices(A, tup))

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


=#

Base.@propagate_inbounds function Base.getindex(a::NamedDimsArray, inds_or_keys::Vararg{Union{
    Integer, Function, Selector, IntervalSets.Domain
    }})
    # Some nonscalar case, will return an array, so need to give that names.
    inds = Base.to_indices(a, inds_or_keys)
    data = Base.getindex(parent(a), inds...)
    L = NamedDims.remaining_dimnames_from_indexing(dimnames(a), inds)
    return NamedDimsArray{L}(data)
end