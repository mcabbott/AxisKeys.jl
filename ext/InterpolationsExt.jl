module InterpolationsExt

using Interpolations
using Interpolations.StaticArrays
using AxisKeys

"""
    KeyedInterpolation{dimnames}(interpolation)

Wrapper for interpolation objects that preserves dimension names and supports key-based access.
Shouldn't be used directly; instead, use `linear_interpolation` or `interpolate` functions.
"""
struct KeyedInterpolation{DNs, TI}
    interpolation::TI
end

KeyedInterpolation(dimnames, interpolation) = KeyedInterpolation{dimnames}(interpolation)
KeyedInterpolation{dimnames}(interpolation) where {dimnames} = KeyedInterpolation{dimnames, typeof(interpolation)}(interpolation)

"""
    linear_interpolation(A::KeyedArray; extrapolation_bc=Throw())

Create a linear interpolation of a KeyedArray that can be called with axiskey values.
Automatically selects BSpline for range keys or Gridded for irregular keys.
"""
function Interpolations.linear_interpolation(A::KeyedArray; extrapolation_bc=Throw())
    it = all(ak -> ak isa AbstractRange, axiskeys(A)) ? BSpline(Linear()) : Gridded(Linear())
    extrapolate(interpolate(A, it), extrapolation_bc)
end

"""
    interpolate(A::KeyedArray, it::Interpolations.DimSpec{BSpline})

Create a BSpline interpolation of a KeyedArray. Requires all axiskeys to be AbstractRanges.
Handles reversed ranges by flipping the array appropriately.
"""
function Interpolations.interpolate(A::KeyedArray, it::Interpolations.DimSpec{BSpline})
    all(ak -> ak isa AbstractRange, axiskeys(A)) || throw(ArgumentError("KeyedArray with BSpline interpolation requires all axiskeys to be AbstractRanges. Use Gridded interpolation instead."))
    if all(ak -> step(ak) > zero(step(ak)), axiskeys(A))
        KeyedInterpolation(dimnames(A), scale(interpolate(parent(A), it), axiskeys(A)...))
    else
        dim_ixs = findall(ak -> step(ak) < zero(step(ak)), axiskeys(A)) |> Tuple
        Ar = reverse(A; dims=dim_ixs)
        interpolate(Ar, it)
    end
end

"""
    interpolate(A::KeyedArray, it::Interpolations.DimSpec{Gridded})

Create a Gridded interpolation of a KeyedArray. Works with irregular axiskey vectors.
Handles reverse-sorted axiskeys by flipping the array appropriately.
"""
function Interpolations.interpolate(A::KeyedArray, it::Interpolations.DimSpec{Gridded})
    if all(issorted, axiskeys(A))
        KeyedInterpolation(dimnames(A), interpolate(axiskeys(A), parent(A), it))
    else
        dim_ixs = findall(ak -> issorted(ak, rev=true), axiskeys(A)) |> Tuple
        Ar = reverse(A; dims=dim_ixs)
        KeyedInterpolation(dimnames(A), interpolate(axiskeys(Ar), parent(Ar), it))
    end
end

"""
    extrapolate(A::KeyedInterpolation, et)

Add extrapolation behavior to a axiskeyed interpolation.
"""
Interpolations.extrapolate(A::KeyedInterpolation, et) = KeyedInterpolation(dimnames(A), extrapolate(A.interpolation, et))

# Call methods for KeyedInterpolation - support positional, tuple, SVector, and named arguments
Base.@propagate_inbounds (ki::KeyedInterpolation)(args::Vararg{Number}) = ki.interpolation(args...)
Base.@propagate_inbounds (ki::KeyedInterpolation)(args::NTuple{<:Any, Number}) = ki.interpolation(args...)
Base.@propagate_inbounds (ki::KeyedInterpolation)(args::SVector) = ki.interpolation(args...)
Base.@propagate_inbounds (ki::KeyedInterpolation)(args::NamedTuple) = ki.interpolation(args[dimnames(ki)]...)
Base.@propagate_inbounds (ki::KeyedInterpolation)(;args...) = ki(NamedTuple(args))

# Gradient methods - support positional, tuple, SVector, and named arguments
Base.@propagate_inbounds Interpolations.gradient(ki::KeyedInterpolation, args::Vararg{Number}) = Interpolations.gradient(ki.interpolation, args...)
Base.@propagate_inbounds Interpolations.gradient(ki::KeyedInterpolation, args::NTuple{<:Any, Number}) = Interpolations.gradient(ki.interpolation, args...)
Base.@propagate_inbounds Interpolations.gradient(ki::KeyedInterpolation, args::SVector) = Interpolations.gradient(ki.interpolation, args...)
Base.@propagate_inbounds function Interpolations.gradient(ki::KeyedInterpolation, args::NamedTuple)  
    keys(args) == dimnames(ki) || throw(ArgumentError("KeyedInterpolation gradient requires keys $(dimnames(ki)) but got $(keys(args))"))
    Interpolations.gradient(ki.interpolation, args...)
end
Base.@propagate_inbounds Interpolations.gradient(ki::KeyedInterpolation; args...) = Interpolations.gradient(ki.interpolation, args[dimnames(ki)]...)

# KeyedInterpolation supports AxisKeys interface
AxisKeys.axiskeys(ki::KeyedInterpolation) = Interpolations.getknots(ki.interpolation)
AxisKeys.named_axiskeys(ki::KeyedInterpolation) = NamedTuple{dimnames(ki)}(axiskeys(ki))
AxisKeys.dimnames(::KeyedInterpolation{DNs}) where {DNs} = DNs

Interpolations.bounds(ki::KeyedInterpolation) = bounds(ki.interpolation)

end
