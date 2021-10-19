using ChainRulesCore

_KeyedArray_pullback(ȳ::AbstractArray, keys) =  (NoTangent(), wrapdims(ȳ; keys...))
_KeyedArray_pullback(ȳ::Tangent, keys) = _KeyedArray_pullback(ȳ.data, keys)
_KeyedArray_pullback(ȳ::AbstractThunk, keys) = _KeyedArray_pullback(unthunk(ȳ), keys)

function ChainRulesCore.rrule(::typeof(keyless_unname), x)
    project_x = ProjectTo(x.data)
    pb(y) = _KeyedArray_pullback(project_x(y), named_axiskeys(x))
    return keyless_unname(x), pb
end