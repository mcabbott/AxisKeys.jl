using ChainRulesCore

_keyless_unname_pullback(ȳ) =  (NoTangent(), ȳ)
_keyless_unname_pullback(ȳ::Tangent) = __keyless_unname_pullback(ȳ.data)
_keyless_unname_pullback(ȳ::AbstractThunk) = _keyless_unname_pullback(unthunk(ȳ))

function ChainRulesCore.rrule(::typeof(keyless_unname), x::KeyedArray)
    project_x = ProjectTo(x.data)
    keyless_unname_pullback(y) = _keyless_unname_pullback(project_x(y))
    return keyless_unname(x), keyless_unname_pullback
end

function ChainRulesCore.rrule(::typeof(keyless_unname), x)
    return keyless_unname(x), _keyless_unname_pullback
end
