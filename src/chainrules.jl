using ChainRulesCore

function ChainRulesCore.ProjectTo(x::Union{KaNda, NdaKa})
    return ProjectTo{KeyedArray}(;data=ProjectTo(keyless_unname(x)), keys=named_axiskeys(x))
end

function ChainRulesCore.ProjectTo(x::KeyedArray)
    return ProjectTo{KeyedArray}(;data=ProjectTo(keyless(x)), keys=axiskeys(x))
end

(project::ProjectTo{KeyedArray})(dx) = wrapdims(project.data(parent(dx)), project.keys...)

_KeyedArray_pullback(ȳ, project) = (NoTangent(), project(ȳ))
_KeyedArray_pullback(ȳ::Tangent, project) = _KeyedArray_pullback(ȳ.data, project)
_KeyedArray_pullback(ȳ::AbstractThunk, project) = _KeyedArray_pullback(unthunk(ȳ), project)

function ChainRulesCore.rrule(::typeof(keyless_unname), x)
    pb(y) = _KeyedArray_pullback(y, ProjectTo(x))
    return keyless_unname(x), pb
end
