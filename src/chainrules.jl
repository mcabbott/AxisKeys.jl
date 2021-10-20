using ChainRulesCore

_keyless_unname_pullback(ȳ) =  (NoTangent(), ȳ)
_keyless_unname_pullback(ȳ::Tangent) = _KeyedArray_pullback(ȳ.data)
_keyless_unname_pullback(ȳ::AbstractThunk) = _KeyedArray_pullback(unthunk(ȳ))

function ChainRulesCore.rrule(::typeof(keyless_unname), x::KeyedArray)
    project_x = ProjectTo(x.data)
    keyless_unname_pb(y) = _keyless_unname_pullback(project_x(y))
    return keyless_unname(x), keyless_unname_pb
end

function ChainRulesCore.rrule(::typeof(keyless_unname), x)
    keyless_unname_pb(y) = _keyless_unname_pullback(y)
    return keyless_unname(x), keyless_unname_pb
end
