using ChainRulesCore

_KeyedArray_pullback(ȳ::AbstractArray) =  (NoTangent(), ȳ)
_KeyedArray_pullback(ȳ::Tangent) = _KeyedArray_pullback(ȳ.data)
_KeyedArray_pullback(ȳ::AbstractThunk) = _KeyedArray_pullback(unthunk(ȳ))

function ChainRulesCore.rrule(::typeof(keyless_unname), x::KeyedArray)
    project_x = ProjectTo(x.data)
    keyless_unname_pb(y) = _KeyedArray_pullback(project_x(y))
    return keyless_unname(x), keyless_unname_pb
end

function ChainRulesCore.rrule(::typeof(keyless_unname), x)
    keyless_unname_pb(y) = (NoTangent(), y)
    return keyless_unname(x), keyless_unname_pb
end
