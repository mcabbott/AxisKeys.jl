
selector_doc = """
    All(val)
    Near(val)
    Between(lo, hi)

These modify indexing according to `ranges(A)`, to match all instead of first,
`B(time = Near(3))` (nearest entry according to `abs2(t-3)` of named dimension `:time`)
or `C(iter = Between(10,20))` (matches `10 <= n <= 20`).
"""

abstract type Selector{T} end

@doc selector_doc
struct All{T} <: Selector{T}
    val::T
end

@doc selector_doc
struct Near{T} <: Selector{T}
    val::T
end

@doc selector_doc
struct Between{T} <: Selector{T}
    lo::T
    hi::T
end
Between(lo,hi) = Between(promote(lo,hi)...)

Base.show(io::IO, s::All{T}) where {T} =
    print(io, "All(",s.val,") ::Selector{",T,"}")

Base.show(io::IO, s::Near{T}) where {T} =
    print(io, "Near(",s.val,") ::Selector{",T,"}")

Base.show(io::IO, s::Between{T}) where {T} =
    print(io, "Between(",s.lo,", ",s.hi,") ::Selector{",T,"}")

findindex(sel::All, range::AbstractArray) = findall(isequal(sel.val), range)

findindex(sel::Near, range::AbstractArray) = argmin(map(x -> abs2(x-sel.val), range))

findindex(sel::Between, range::AbstractArray) = findall(x -> sel.lo <= x <= sel.hi, range)

"""
    Index[i]

This exists to let you mix in square-bracket indexing,
like `A(:b, Near(3.14), Index[4:5], "f")`.
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
