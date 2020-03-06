
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

See also `Index[i]`.
"""
abstract type Selector{T} end

Base.eltype(::Type{<:Selector{T}}) where {T} = T

@doc @doc(Selector)
struct Near{T} <: Selector{T}
    val::T
end

Base.eltype(s::Near{T}) where {T} = T
Base.show(io::IO, s::Near) = print(io, "Near(",s.val,")")
Base.show(io::IO, ::MIME"text/plain", s::Near{T}) where {T} =
    print(io, "Near(",s.val,") ::Selector{",T,"}")

findindex(sel::Near, range::AbstractArray) = argmin(map(x -> abs2(x-sel.val), range))

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
