
"""
    wrapdims(A, :i, :j)
    wrapdims(A, 1:10, ['a', 'b', 'c'])
    wrapdims(A, i=1:10, j=['a', 'b', 'c'])

Function for constructing either a `NamedDimsArray`, a `RangeArray`,
or a nested pair of both.

Performs some sanity checks which are skipped by `RangeArray` constructor.
Giving `nothing` as a range will result in `ranges(A,d) == axes(A,d)`.
Given an `AbstractRange` of the wrong length, it will adjust the end of the range,
and give a warning.

By default it wraps in this order: `RangeArray{...,NamedDimsArray{...}}`.
This tests a flag `AxisRanges.OUTER[] == :RangeArray` which you can change.
"""
wrapdims(A::AbstractArray, r::Union{AbstractVector,Nothing}, ranges::Union{AbstractVector,Nothing}...) =
    RangeArray(A, check_ranges(A, (r, ranges...)))

"""
    wrapdims(T, ranges...)
    wrapdims(T; name=range, ...)

Given a type `T`, this creates `Array{T}(undef, ...)` before wrapping as instructed.
"""
wrapdims(T::Type, r::AbstractVector, ranges::AbstractVector...) =
    wrapdims(Array{T}(undef, map(length, (r, ranges...))), r, ranges...)

using OffsetArrays

function check_ranges(A, ranges)
    ndims(A) == length(ranges) || throw(ArgumentError(
        "wrong number of ranges, got $(length(ranges)) with ndims(A) == $(ndims(A))"))
    checked = ntuple(ndims(A)) do d
        r = ranges[d]
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
    ndims(A) == 1 ? Ref(first(checked)) : checked
end

extend_range(r::AbstractRange, l::Int) = range(first(r), step=step(r), length=l)
extend_range(r::StepRange{Char,Int}, l::Int) = StepRange(first(r), step(r), first(r)+l-1)
extend_range(r::AbstractUnitRange, l::Int) = range(first(r), length=l)
extend_range(r::OneTo, l::Int) = OneTo(l)

#===== With names =====#

wrapdims(A::AbstractArray, n::Symbol, names::Symbol...) =
    NamedDimsArray(A, check_names(A, (n, names...)))

const OUTER = Ref(:RangeArray)

function wrapdims(A::AbstractArray; kw...)
    L = check_names(A, kw.itr)
    R = check_ranges(A, values(kw.data))
    if OUTER[] == :RangeArray
        return RangeArray(NamedDimsArray(A, L), R)
    else
        return NamedDimsArray(RangeArray(A, R), L)
    end
end

function check_names(A, names)
    ndims(A) == length(names) || throw(ArgumentError(
        "wrong number of names, got $names with ndims(A) == $(ndims(A))"))
    names
end
