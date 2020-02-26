
using LazyStack

# for stack_iter
LazyStack.no_wraps(a::RangeArray) = LazyStack.no_wraps(NamedDims.unname(parent(a)))

function LazyStack.rewrap_like(A, a::RangeArray)
    B = LazyStack.rewrap_like(A, parent(a))
    RangeArray(B, (ranges(a)..., ntuple(d -> ranges_or_axes(B, d + ndims(a)), ndims(A) - ndims(a))...))
end

function LazyStack.rewrap_like(A, a::NamedTuple)
    RangeArray(A, (collect(keys(a)), ntuple(d -> ranges_or_axes(A, d + 1), ndims(A) - 1)...))
end

# tuple of arrays
function LazyStack.stack(x::AT) where {AT <: Tuple{Vararg{RangeArray{T,IN}}}} where {T,IN}
    RangeArray(LazyStack.stack(map(parent, x)), stack_ranges(x))
end

stack_ranges(xs::Tuple{Vararg{<:RangeArray}}) =
    (ranges_or_axes(first(xs))..., Base.OneTo(length(xs)))

# array of arrays: first strip off outer containers...
function LazyStack.stack(xs::RangeArray{<:AbstractArray})
    RangeArray(stack(parent(xs)), stack_ranges(xs))
end
function LazyStack.stack(xs::RangeArray{<:AbstractArray,N,<:NamedDimsArray{L}}) where {L,N}
    data = stack(parent(parent(xs)))
    RangeArray(LazyStack.ensure_named(data, LazyStack.getnames(xs)), stack_ranges(xs))
end
function LazyStack.stack(xs::NamedDimsArray{L,<:AbstractArray,N,<:RangeArray}) where {L,N}
    data = stack(parent(parent(xs)))
    LazyStack.ensure_named(RangeArray(data, stack_ranges(xs)), LazyStack.getnames(xs))
end

# ... then deal with inner ones:
function LazyStack.stack(x::AT) where {AT <: AbstractArray{<:RangeArray{T,IN},ON}} where {T,IN,ON}
    RangeArray(LazyStack.Stacked{T, IN+ON, AT}(x), stack_ranges(x))
end
function LazyStack.stack(x::AT) where {AT <: AbstractArray{<:RangeArray{T,IN,IT},ON}} where {IT<:NamedDimsArray} where {T,IN,ON}
    data = LazyStack.Stacked{T, IN+ON, AT}(x)
    RangeArray(NamedDimsArray(data, LazyStack.getnames(x)), stack_ranges(x))
end
function LazyStack.stack(x::AT) where {AT <: AbstractArray{<:NamedDimsArray{L,T,IN,IT},ON}} where {IT<:RangeArray} where {T,IN,ON,L}
    data = LazyStack.Stacked{T, IN+ON, AT}(x)
    NamedDimsArray(RangeArray(data, stack_ranges(x)), LazyStack.getnames(x))
end

stack_ranges(xs::AbstractArray{<:AbstractArray}) =
    (ranges_or_axes(first(xs))..., ranges_or_axes(xs)...)

function LazyStack.getnames(xs::RangeArray{<:AbstractArray,N,OT}) where {N,OT}
    (dimnames(eltype(xs))..., dimnames(OT)...)
end
function LazyStack.getnames(xs::AbstractArray{<:RangeArray{T,N,IT}}) where {T,N,IT}
    out_names = hasnames(xs) ? names(xs) : NamedDims.dimnames(xs)
    (NamedDims.dimnames(IT)..., out_names...)
end
