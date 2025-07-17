module InterpolationsExt

using Interpolations
using Interpolations.StaticArrays
using AxisKeys


struct KeyedInterpolation{DNs, TI}
    interpolation::TI
end

KeyedInterpolation(dimnames, interpolation) = KeyedInterpolation{dimnames}(interpolation)
KeyedInterpolation{dimnames}(interpolation) where {dimnames} = KeyedInterpolation{dimnames, typeof(interpolation)}(interpolation)

function Interpolations.linear_interpolation(A::KeyedArray; extrapolation_bc=Throw())
    it = all(ak -> ak isa AbstractRange, axiskeys(A)) ? BSpline(Linear()) : Gridded(Linear())
    extrapolate(interpolate(A, it), extrapolation_bc)
end

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

function Interpolations.interpolate(A::KeyedArray, it::Interpolations.DimSpec{Gridded})
    if all(issorted, axiskeys(A))
        KeyedInterpolation(dimnames(A), interpolate(axiskeys(A), parent(A), it))
    else
        dim_ixs = findall(ak -> issorted(ak, rev=true), axiskeys(A)) |> Tuple
        Ar = reverse(A; dims=dim_ixs)
        KeyedInterpolation(dimnames(A), interpolate(axiskeys(Ar), parent(Ar), it))
    end
end

Interpolations.extrapolate(A::KeyedInterpolation, et) = KeyedInterpolation(dimnames(A), extrapolate(A.interpolation, et))

Base.@propagate_inbounds (ki::KeyedInterpolation)(args::Vararg{Number}) = ki.interpolation(args...)
Base.@propagate_inbounds (ki::KeyedInterpolation)(args::NTuple{<:Any, Number}) = ki.interpolation(args...)
Base.@propagate_inbounds (ki::KeyedInterpolation)(args::SVector) = ki.interpolation(args...)
Base.@propagate_inbounds (ki::KeyedInterpolation)(args::NamedTuple) = ki.interpolation(args[dimnames(ki)]...)
Base.@propagate_inbounds (ki::KeyedInterpolation)(;args...) = ki(NamedTuple(args))

Base.@propagate_inbounds Interpolations.gradient(ki::KeyedInterpolation, args::Vararg{Number}) = Interpolations.gradient(ki.interpolation, args...)
Base.@propagate_inbounds Interpolations.gradient(ki::KeyedInterpolation, args::NTuple{<:Any, Number}) = Interpolations.gradient(ki.interpolation, args...)
Base.@propagate_inbounds Interpolations.gradient(ki::KeyedInterpolation, args::SVector) = Interpolations.gradient(ki.interpolation, args...)
Base.@propagate_inbounds function Interpolations.gradient(ki::KeyedInterpolation, args::NamedTuple)  
    keys(args) == dimnames(ki) || throw(ArgumentError("KeyedInterpolation gradient requires keys $(dimnames(ki)) but got $(keys(args))"))
    Interpolations.gradient(ki.interpolation, args...)
end
Base.@propagate_inbounds Interpolations.gradient(ki::KeyedInterpolation; args...) = Interpolations.gradient(ki.interpolation, args[dimnames(ki)]...)

AxisKeys.axiskeys(ki::KeyedInterpolation) = Interpolations.getknots(ki.interpolation)
AxisKeys.named_axiskeys(ki::KeyedInterpolation) = NamedTuple{dimnames(ki)}(axiskeys(ki))
AxisKeys.dimnames(::KeyedInterpolation{DNs}) where {DNs} = DNs

Interpolations.bounds(ki::KeyedInterpolation) = bounds(ki.interpolation)

end
