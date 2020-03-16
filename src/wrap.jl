
"""
    wrapdims(A, :i, :j)
    wrapdims(A, 1:10, ['a', 'b', 'c'])
    wrapdims(A, i=1:10, j=['a', 'b', 'c'])

Convenience function for constructing either a `NamedDimsArray`, a `KeyedArray`,
or a nested pair of both.

Performs some sanity checks which are skipped by `KeyedArray` constructor:
* Giving `nothing` instead of keys will result in `axiskeys(A,d) == axes(A,d)`.
* Given an `AbstractRange` of the wrong length, it will adjust the end of this,
  and give a warning.
* Given `A::OffsetArray` and key vectors which are not, it will wrap them so that
  `axes.(axiskeys(A_wrapped)) == axes(A)`.

By default it wraps in this order: `KeyedArray{...,NamedDimsArray{...}}`.
This tests a flag `AxisKeys.OUTER[] == :KeyedArray` which you can change.
"""
wrapdims(A::AbstractArray, r::Union{AbstractVector,Nothing}, keys::Union{AbstractVector,Nothing}...) =
    KeyedArray(A, check_keys(A, (r, keys...)))

"""
    wrapdims(A, T, keyvecs...)
    wrapdims(A, T; name=keyvec...)

This applies type `T` to all of the keys,
for example to wrap them as `UniqueVector`s or `AcceleratedArray`s (using those packages)
for fast lookup.
"""
wrapdims(A::AbstractArray, T::Type, r::Union{AbstractVector,Nothing}, keys::Union{AbstractVector,Nothing}...) =
    KeyedArray(A, map(T, check_keys(A, (r, keys...))))

"""
    wrapdims(T, keys...)
    wrapdims(T; name=range, ...)

Given a datatype `T`, this creates `Array{T}(undef, ...)` before wrapping as instructed.
"""
wrapdims(T::Type, r::AbstractVector, keys::AbstractVector...) =
    wrapdims(Array{T}(undef, map(length, (r, keys...))), r, keys...)

using OffsetArrays

function check_keys(A, keys)
    ndims(A) == length(keys) || throw(ArgumentError(
        "wrong number of key vectors, got $(length(keys)) with ndims(A) == $(ndims(A))"))
    checked = ntuple(ndims(A)) do d
        r = keys[d]
        if r === nothing
            axes(A,d)
        elseif axes(r,1) == axes(A,d)
            r
        elseif length(r) == size(A,d)
            OffsetArray(r, axes(A,d))
        elseif r isa AbstractRange
            l = size(A,d)
            r′ = extend_range(r, l)
            l > 0 && @warn "range $r replaced by $r′, to match size(A, $d) == $l" maxlog=1 _id=hash(r)
            r′
        else
            throw(DimensionMismatch("length of range does not match size of array: size(A, $d) == $(size(A,d)) != length(r) == $(length(r)), for range r = $r"))
        end
    end
end

extend_range(r::AbstractRange, l::Int) = range(first(r), step=step(r), length=l)
extend_range(r::StepRange{Char,Int}, l::Int) = StepRange(first(r), step(r), first(r)+l-1)
extend_range(r::AbstractUnitRange, l::Int) = range(first(r), length=l)
extend_range(r::OneTo, l::Int) = OneTo(l)

#===== With names =====#

wrapdims(A::AbstractArray, n::Symbol, names::Symbol...) =
    NamedDimsArray(A, check_names(A, (n, names...)))

const OUTER = Ref(:KeyedArray)

function wrapdims(A::AbstractArray, T::Union{Type,Function}=identity; kw...)
    L = check_names(A, keys(kw))
    R = map(T, check_keys(A, values(values(kw))))
    if OUTER[] == :KeyedArray
        return KeyedArray(NamedDimsArray(A, L), R)
    else
        return NamedDimsArray(KeyedArray(A, R), L)
    end
end

function check_names(A, names)
    ndims(A) == length(names) || throw(ArgumentError(
        "wrong number of names, got $names with ndims(A) == $(ndims(A))"))
    names
end

_construc_doc = """
    KeyedArray(A; i=2:3, j=["a", "b"])
    NamedDimsArray(A; i=2:3, j=["a", "b"])

These constructors make `KeyedArray(NamedDimsArray(A, names), keys)`
or `NamedDimsArray(KeyedArray(A, keys), names)`, which should be equivalent.

These perform less sanity checking than `wrapdims(A; kw...)`.
"""
@doc _construc_doc
function KeyedArray(A::AbstractArray; kw...)
    L = keys(kw)
    length(L) == ndims(A) || throw(ArgumentError("number of names must match number of dimensions"))
    R = values(values(kw))
    axes.(R, 1) == axes(A) || throw(ArgumentError("axes of keys must match axes of array"))
    KeyedArray(NamedDimsArray(A, L), R)
end

@doc _construc_doc
function NamedDims.NamedDimsArray(A::AbstractArray; kw...)
    L = keys(kw)
    length(L) == ndims(A) || throw(ArgumentError("number of names must match number of dimensions"))
    R = values(values(kw))
    axes.(R, 1) == axes(A) || throw(ArgumentError("axes of keys must match axes of array"))
    NamedDimsArray(KeyedArray(A, R), L)
end
