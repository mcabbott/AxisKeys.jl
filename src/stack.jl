
using LazyStack

# for stack_iter
LazyStack.no_wraps(a::KeyedArray) = LazyStack.no_wraps(NamedDims.unname(parent(a)))

function LazyStack.rewrap_like(A, a::KeyedArray)
    B = LazyStack.rewrap_like(A, parent(a))
    KeyedArray(B, (axiskeys(a)..., ntuple(d -> keys_or_axes(B, d + ndims(a)), ndims(A) - ndims(a))...))
end

function LazyStack.rewrap_like(A, a::NamedTuple)
    KeyedArray(A, (collect(keys(a)), ntuple(d -> keys_or_axes(A, d + 1), ndims(A) - 1)...))
end

# tuple of arrays
function LazyStack.stack(x::Tuple{Vararg{KeyedArray}})
    KeyedArray(LazyStack.stack(map(parent, x)), stack_keys(x))
end

stack_keys(xs::Tuple{Vararg{KeyedArray}}) =
    (keys_or_axes(first(xs))..., Base.OneTo(length(xs)))

# array of arrays: first strip off outer containers...
function LazyStack.stack(xs::KeyedArray{<:AbstractArray})
    KeyedArray(stack(parent(xs)), stack_keys(xs))
end
function LazyStack.stack(xs::KeyedArray{<:AbstractArray,N,<:NamedDimsArray{L}}) where {L,N}
    data = stack(parent(parent(xs)))
    KeyedArray(LazyStack.ensure_named(data, LazyStack.getnames(xs)), stack_keys(xs))
end
function LazyStack.stack(xs::NamedDimsArray{L,<:AbstractArray,N,<:KeyedArray}) where {L,N}
    data = stack(parent(parent(xs)))
    LazyStack.ensure_named(KeyedArray(data, stack_keys(xs)), LazyStack.getnames(xs))
end

# ... then deal with inner ones:
function LazyStack.stack(x::AT) where {AT <: AbstractArray{<:KeyedArray{T,IN},ON}} where {T,IN,ON}
    KeyedArray(LazyStack.Stacked{T, IN+ON, AT}(x), stack_keys(x))
end
function LazyStack.stack(x::AT) where {AT <: AbstractArray{<:KeyedArray{T,IN,IT},ON}} where {IT<:NamedDimsArray} where {T,IN,ON}
    data = LazyStack.Stacked{T, IN+ON, AT}(x)
    KeyedArray(NamedDimsArray(data, LazyStack.getnames(x)), stack_keys(x))
end
function LazyStack.stack(x::AT) where {AT <: AbstractArray{<:NamedDimsArray{L,T,IN,IT},ON}} where {IT<:KeyedArray} where {T,IN,ON,L}
    data = LazyStack.Stacked{T, IN+ON, AT}(x)
    NamedDimsArray(KeyedArray(data, stack_keys(x)), LazyStack.getnames(x))
end

stack_keys(xs::AbstractArray{<:AbstractArray}) =
    (keys_or_axes(first(xs))..., keys_or_axes(xs)...)

function LazyStack.getnames(xs::KeyedArray{<:AbstractArray,N,OT}) where {N,OT}
    (dimnames(eltype(xs))..., dimnames(OT)...)
end
function LazyStack.getnames(xs::AbstractArray{<:KeyedArray{T,N,IT}}) where {T,N,IT}
    out_names = hasnames(xs) ? dimnames(xs) : NamedDims.dimnames(xs)
    (NamedDims.dimnames(IT)..., out_names...)
end
