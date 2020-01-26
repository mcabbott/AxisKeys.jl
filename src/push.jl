#=
These functions are the reason RangeArray's ranges are Ref not Tuple when ndims==1.
They should always change A.ranges[] to have the right length,
but if the type doesn't fit, then return something not === to original
=#

"""
    push!(A::RangeArray, val)

This adds `val` to the end of `A.data`, and attempts to extend `ranges(A,1)` by one.
"""
function Base.push!(A::RangeArray, val)
    data = push!(parent(A), val)
    old_range = ranges(A,1)
    new_range = extend_one!!(old_range)
    if new_range === old_range  # then it was mutated, best case
        return A
    elseif typeof(new_range) <: typeof(old_range)  # will fit into same container
        setindex!(A.ranges, new_range)
        return A
    else  # we can't fix A, but can return correct thing
        return RangeArray(data, (new_range,))
    end
end

function Base.pop!(A::RangeArray)
    val = pop!(parent(A))
    old_range = ranges(A,1)
    new_range = shorten_one!!(old_range)
    if new_range === old_range
    elseif typeof(new_range) <: typeof(old_range)
        setindex!(A.ranges, new_range)
    else
        error("failed to shorten range of array")
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

function Base.append!(A::RangeArray, B)
    data = append!(parent(A), B)
    old_range = ranges(A,1)
    new_range = extend_by!!(old_range, length(B))
    if new_range === old_range
        return A
    elseif typeof(new_range) <: typeof(old_range)
        setindex!(A.ranges, new_range)
        return A
    else
        return RangeArray(data, (new_range,))
    end
end
function Base.append!(A::RangeArray, B::RangeArray)
    data = append!(parent(A), parent(B))
    old_range = ranges(A,1)
    new_range = append!!(old_range, ranges(B,1))
    if new_range === old_range
        return A
    elseif typeof(new_range) <: typeof(old_range)
        setindex!(A.ranges, new_range)
        return A
    else
        return RangeArray(data, (new_range,))
    end
end

extend_by!!(r::Base.OneTo, n::Int) = Base.OneTo(last(r)+n)
extend_by!!(r::UnitRange{Int}, n::Int) = UnitRange(r.start, r.stop + n)
extend_by!!(r::StepRange{<:Any,Int}, n::Int) = StepRange(r.start, r.step, r.stop + n * r.step)
extend_by!!(r::Vector{<:Number}, n::Int) = append!(r, length(r)+1 : length(r)+n+1)
extend_by!!(r::AbstractVector, n::Int) = vcat(r, length(r)+1 : length(r)+n+1)

append!!(r::Vector, s::AbstractVector) = append!(r,s)
append!!(r::AbstractVector, s::AbstractVector) = (extend_by!!(r, length(s)); vcat(r,s))

#=
This doesn't extend A's range, hence leaves incoherent state...
A = wrapdims(rand(3), 'a':'c'); push!(A, 'd' => 4)
Should it call extend_by!!(old_range) perhaps?
=#
"""
    A′ = push!(A::RangeArray; key = val)
    A′ = push!(A::RangeArray, key => val)

This pushes `val` into `A.data`, and pushes or appends `key` to `ranges(A,1)`.
This may leave `A` in an incoherent state, but the returned `A′` is sure to be safe.
"""
Base.push!(A::RangeArray; kw...) = push!(A, map(Pair, keys(kw), values(kw.data))...)

function Base.push!(A::RangeArray, p::Pair...)
    data = push!(parent(A), map(last, p)...)
    old_range = ranges(A,1)
    new_range = push_or_cat!!(old_range, map(first, p)...)
    if new_range === old_range  # then it was mutated, best case
        return A
    elseif typeof(new_range) <: typeof(old_range) # will fit into same container
        setindex!(A.ranges, new_range)
        return A
    end
    # We can't fix A, but try to at least keep it coherent?
    if length(new_range) != length(old_range)
        dummy = extend_by!!(old_range, length(new_range) - length(old_range))
        typeof(dummy) <: typeof(old_range) && setindex!(A.ranges, dummy)
    end
    RangeArray(data, (new_range,)) # ... and return the correct thing
end

push_or_cat!!(A::AbstractRange, vals...) = vcat(A, vals...)
push_or_cat!!(A::AbstractVector, vals...) = push!(A, vals...)
