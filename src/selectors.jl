
selector_doc = """
    Nearest(val)
    Between(lo, hi)

These selectors modify lookup using `ranges(A)`:
`B(time = Nearest(3))` matches one entry with minimum `abs2(t-3)` of named dimension `:time`.
`C("cat", Between(10,20))` matches all entries with `10 <= iter <= 20`).

    ==(val)
    <(val)

Note that any functions can be used similarly, like C(!=("dog"), <=(33)).
They ultimately call `findall(==(val), range(A,d))`.

Functions of type `Base.Fix2`, and `Selector`s, also allow a dimension
to be chose by `eltype`, provided `map(eltype, ranges(A))` are all unique.

See also `Index[i]`.
"""

abstract type Selector{T} end

@doc selector_doc
struct Nearest{T} <: Selector{T}
    val::T
end

@doc selector_doc
struct Between{T} <: Selector{T}
    lo::T
    hi::T
end
Between(lo,hi) = Between(promote(lo,hi)...)

Base.eltype(s::Nearest{T}) where {T} = T
Base.show(io::IO, s::Nearest{T}) where {T} =
    print(io, "Nearest(",s.val,") ::Selector{",T,"}")

Base.eltype(s::Between{T}) where {T} = T
Base.show(io::IO, s::Between{T}) where {T} =
    print(io, "Between(",s.lo,", ",s.hi,") ::Selector{",T,"}")

findindex(sel::Nearest, range::AbstractArray) = argmin(map(x -> abs2(x-sel.val), range))

findindex(sel::Between, range::AbstractArray) = findall(x -> sel.lo <= x <= sel.hi, range)

"""
    Index[i]

This exists to let you mix in square-bracket indexing,
like `A(:b, Nearest(3.14), Index[4:5], "f")`.
You may also write `Index[end]`, although not yet `Index[end-2]`.
"""
struct Index{T} <: Selector{T}
    ind::T
end

Base.show(io::IO, s::Index{T}) where {T} = print(io, "Index(",s.ind, ")")

Base.getindex(::Type{Index}, i) = Index(i)

findindex(sel::Index, range::AbstractArray) = sel.ind

struct LastIndex <: Selector{Int} end

Base.lastindex(::Type{Index}) = LastIndex()

Index(::LastIndex) = LastIndex()

findindex(sel::LastIndex, range::AbstractArray) = lastindex(range)
