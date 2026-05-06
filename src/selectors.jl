using IntervalSets

findindex(int::Interval, r::AbstractVector) =
    findall(x -> x in int, r)
findindex(int::Interval, r::AbstractRange{T}) where {T<:Union{Number,Char}} =
    findall(in(int), r)

# find interval in a vector of intervals: same as generic findindex in lookup.jl
function findindex(int::Interval, r::AbstractVector{<:Interval})
    i = findfirst(isequal(int), r)
    i === nothing && throw(ArgumentError("could not find key $(repr(a)) in vector $r"))
    i
end

# Since that is now efficient for ranges, comparisons can go there:

findindex(eq::Base.Fix2{typeof(<=)}, r::AbstractRange{T}) where {T<:Union{Number,Char}} =
    findall(in(Interval(typemin(T), eq.x)), r)

findindex(eq::Base.Fix2{typeof(>=)}, r::AbstractRange{T}) where {T<:Union{Number,Char}} =
    findall(in(Interval(eq.x, typemax(T))), r)

findindex(eq::Base.Fix2{typeof(<)}, r::AbstractRange{T}) where {T<:Union{Number,Char}} =
    findall(in(Interval{:closed, :open}(typemin(T), eq.x)), r)

findindex(eq::Base.Fix2{typeof(>)}, r::AbstractRange{T}) where {T<:Union{Number,Char}} =
    findall(in(Interval{:open, :closed}(eq.x, typemax(T))), r)


"""
    Near(val)
    Interval(lo, hi)

These selectors modify lookup using `axiskeys(A)`:
`B(time = Near(3))` matches one entry with minimum `abs(t-3)` of named dimension `:time`.
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

# Examples
```jldoctest
julia> v = KeyedArray(Symbol.('a':'e'), 10:10:50)
1-dimensional KeyedArray(...) with keys:
↓   5-element StepRange{Int64,...}
And data, 5-element Vector{Symbol}:
 (10)  :a
 (20)  :b
 (30)  :c
 (40)  :d
 (50)  :e

julia> v[Near(33)]
:c

julia> v[==(30)]  # all matching this key
1-dimensional KeyedArray(...) with keys:
↓   1-element Vector{Int64}
And data, 1-element Vector{Symbol}:
 (30)  :c

julia> v[Interval(17, 31)]
1-dimensional KeyedArray(...) with keys:
↓   2-element StepRange{Int64,...}
And data, 2-element Vector{Symbol}:
 (20)  :b
 (30)  :c

julia> m = wrapdims(hcat(v,v), x=nothing, y=[:left, :right]);

julia> m(<(30))  # selects 1st dim by type, and makes a view
2-dimensional KeyedArray(NamedDimsArray(...)) with keys:
↓   x ∈ 2-element StepRange{Int64,...}
→   y ∈ 2-element Vector{Symbol}
And data, 2×2 view(::Matrix{Symbol}, 1:2, :) with eltype Symbol:
       (:left)  (:right)
 (10)    :a       :a
 (20)    :b       :b
```
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
    iplus = searchsortedfirst(range, sel.val; rev=step(range) < zero(step(range)))
    # "index of the first value in a greater than or equal to x"
    iplus == firstindex(range) && return 1
    iplus > lastindex(range) && return lastindex(range)
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

# Examples
```jldoctest
julia> v = KeyedArray(Symbol.('a':'e'), 10:10:50)
1-dimensional KeyedArray(...) with keys:
↓   5-element StepRange{Int64,...}
And data, 5-element Vector{Symbol}:
 (10)  :a
 (20)  :b
 (30)  :c
 (40)  :d
 (50)  :e

julia> v[Key(30)] == v(30) == v(Index[3]) == v[3]
true

julia> v[==(30)] == v(Index[3:3]) == v[3:3]
true
```
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

struct FirstIndex <: Selector{Int} end
Base.firstindex(::Type{Index}) = FirstIndex()
Index(::FirstIndex) = FirstIndex()
findindex(sel::FirstIndex, range::AbstractArray) = firstindex(range)

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

using Base: to_indices, tail, safe_tail, uncolon

@inline Base.to_indices(A::Union{KeyedArray,NdaKa}, inds, I::Tuple{Colon, Vararg{Any}}) =
    (uncolon(inds), to_indices(A, safe_tail(inds), tail(I))...)

