#=
These functions are the reason KeyedArray's keys are Ref not Tuple when ndims==1.
They should always change A.keys[] to have the right length,
but if the type doesn't fit, then return something not === to original
=#

"""
    push!(A::KeyedArray, val)

This adds `val` to the end of `pareent(A)`, and attempts to extend `axiskeys(A,1)` by one.
"""
function Base.push!(A::KeyedArray, val)
    data = push!(parent(A), val)
    old_keys = axiskeys(A,1)
    new_keys = extend_one!!(old_keys)
    if new_keys === old_keys  # then it was mutated, best case
        return A
    elseif typeof(new_keys) <: typeof(old_keys)  # will fit into same container
        setindex!(A.keys, new_keys)
        return A
    else  # we can't fix A, but can return correct thing
        return KeyedArray(data, (new_keys,))
    end
end

function Base.pop!(A::KeyedArray)
    val = pop!(parent(A))
    old_keys = axiskeys(A,1)
    new_keys = shorten_one!!(old_keys)
    if new_keys === old_keys
    elseif typeof(new_keys) <: typeof(old_keys)
        setindex!(A.keys, new_keys)
    else
        error("failed to shorten keys of array")
    end
    val
end

extend_one!!(r::Base.OneTo) = Base.OneTo(last(r)+1)
extend_one!!(r::UnitRange{Int}) = UnitRange(r.start, r.stop + 1)
extend_one!!(r::StepRange{<:Any,Int}) = StepRange(r.start, r.step, r.stop + r.step)
extend_one!!(r::Vector{<:Number}) = push!(r, length(r)+1)
extend_one!!(r::AbstractVector) = vcat(r, length(r)+1)

shorten_one!!(r::Base.OneTo) = Base.OneTo(last(r)-1)
shorten_one!!(r::Vector) = pop!(r)
shorten_one!!(r::AbstractVector) = r[1:end-1]

function Base.append!(A::KeyedArray, B)
    data = append!(parent(A), B)
    old_keys = axiskeys(A,1)
    new_keys = extend_by!!(old_keys, length(B))
    if new_keys === old_keys
        return A
    elseif typeof(new_keys) <: typeof(old_keys)
        setindex!(A.keys, new_keys)
        return A
    else
        return KeyedArray(data, (new_keys,))
    end
end
function Base.append!(A::KeyedArray, B::KeyedArray)
    data = append!(parent(A), parent(B))
    old_keys = axiskeys(A,1)
    new_keys = append!!(old_keys, axiskeys(B,1))
    if new_keys === old_keys
        return A
    elseif typeof(new_keys) <: typeof(old_keys)
        setindex!(A.keys, new_keys)
        return A
    else
        return KeyedArray(data, (new_keys,))
    end
end

extend_by!!(r::Base.OneTo, n::Int) = Base.OneTo(last(r)+n)
extend_by!!(r::UnitRange{Int}, n::Int) = UnitRange(r.start, r.stop + n)
extend_by!!(r::StepRange{<:Any,Int}, n::Int) = StepRange(r.start, r.step, r.stop + n * r.step)
extend_by!!(r::Vector{<:Number}, n::Int) = append!(r, length(r)+1 : length(r)+n+1)
extend_by!!(r::AbstractVector, n::Int) = vcat(r, length(r)+1 : length(r)+n+1)

append!!(r::Vector, s::AbstractVector) = append!(r,s)
append!!(r::AbstractVector, s::AbstractVector) = (extend_by!!(r, length(s)); vcat(r,s))

"""
    push!(A::KeyedArray; key = val)
    push!(A::KeyedArray, key => val)

This pushes `val` into `A.data`, and pushes `key` to `axiskeys(A,1)`.
Both of these must be legal operations, e.g. `A = wrapdims([1], ["a"]); push!(A, b=2)`.
"""
Base.push!(A::KeyedArray; kw...) = push!(A, map(Pair, keys(kw), values(kw.data))...)

function Base.push!(A::KeyedArray, pairs::Pair...)
    axiskeys(A,1) isa AbstractRange && error("can't use push!(A, key => val) when axiskeys(A,1) isa AbstractRange")
    T = eltype(axiskeys(A,1))
    push!(axiskeys(A,1),  map(p -> T(first(p)), pairs)...)
    push!(parent(A), map(last, pairs)...)
    A
end
