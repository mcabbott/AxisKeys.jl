
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

By default it wraps in this order: `KeyedArray{...,NamedDimsArray{...}}`,
which you can change by re-defining `AxisKeys.nameouter() == true`.
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
            throw(DimensionMismatch("length of key vector does not match size of array: size(A, $d) == $(size(A,d)) != length(r) == $(length(r)), for range r = $r"))
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

nameouter() = false # re-definable function

function wrapdims(A::AbstractArray, KT::Union{Type,Function}=identity; kw...)
    L0 = keys(values(kw))
    length(L0) == 0 && return wrapdims_import(A)
    L = check_names(A, L0)
    R = map(KT, check_keys(A, values(values(kw))))
    if nameouter() == false
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

#===== Conversions to & from NamedTuples =====#

"""
    wrapdims(::NamedTuple)
    wrapdims(::NamedTuple, ::Symbol)

Converts the `NamedTuple`'s keys into those of a one-dimensional `KeyedArray`.
If a dimension name is provided, the this adds a `NamedDimsArray` wrapper too.
"""
wrapdims(nt::NamedTuple) = KeyedArray(nt)
KeyedArray(nt::NamedTuple) = KeyedArray(collect(values(nt)), tuple(collect(keys(nt))))

function wrapdims(nt::NamedTuple, s::Symbol)
    if nameouter() == false
        return KeyedArray(NamedDimsArray(collect(values(nt)), (s,)), tuple(collect(keys(nt))))
    else
        return NamedDimsArray(KeyedArray(nt), (s,))
    end
end

function Base.NamedTuple(A::KeyedVector)
    keys = map(Symbol, Tuple(axiskeys(A,1)))
    vals = Tuple(keyless(A))
    NamedTuple{keys}(vals)
end
Base.NamedTuple(A::NamedDimsArray{L,T,1,<:KeyedVector}) where {L,T} = NamedTuple(parent(A))

Base.convert(::Type{NamedTuple}, A::KeyedVector) = NamedTuple(A)
Base.convert(::Type{NamedTuple}, A::NamedDimsArray{L,T,1,<:KeyedVector}) where {L,T} = NamedTuple(A)

#===== Conversions from NamedArrays etc =====#

"""
    wrapdims(A::NamedArray)
    wrapdims(A::AxisArray)

Converts the wrapper from packages NamedArrays.jl or AxisArrays.jl.
(Really it just guesses based on field names, since these packages are not loaded.)
"""
function wrapdims end

function wrapdims_import(A::AbstractArray)
    fields = fieldnames(typeof(A))

    if fields == (:array, :dicts, :dimnames) # then it's a NamedArray
        keys = map(A.dicts) do d
            v = d.keys # usually a vector of strings
            if v isa AbstractVector{<:AbstractString}
                vi = tryparse.(Int, v)
                any(i -> i==nothing, vi) || return vi
                vr = tryparse.(Float64, v)
                any(r -> r==nothing, vr) || return vr
            end
            v
        end
        if nameouter() == false
            return KeyedArray(NamedDimsArray(A.array, A.dimnames), keys)
        else
            return NamedDimsArray(KeyedArray(A.array, keys), A.dimnames)
        end

    elseif fields == (:data, :axes) # then it's an AxisArray
        keys = map(a -> a.val, A.axes)
        names = map(a -> typeof(a).parameters[1], A.axes)
        if nameouter() == false
            return KeyedArray(NamedDimsArray(A.data, names), keys)
        else
            return NamedDimsArray(KeyedArray(A.data, keys), names)
        end

    else # just wrap it
        return KeyedArray(A, axes(A))
    end
end
