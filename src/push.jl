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

"""
    push!(A::RangeArray; key = val)
    push!(A::RangeArray, key => val)

This pushes `val` into `A.data`, and pushes `key` to `ranges(A,1)`.
Both of these must be legal operations, e.g. `A = wrapdims([1], ["a"]); push!(A, b=2)`.
"""
Base.push!(A::RangeArray; kw...) = push!(A, map(Pair, keys(kw), values(kw.data))...)

function Base.push!(A::RangeArray, pairs::Pair...)
    ranges(A,1) isa AbstractRange && error("can't use push!(A, key => val) when range(A,1) isa AbstractRange")
    T = eltype(ranges(A,1))
    push!(ranges(A,1),  map(p -> T(first(p)), pairs)...)
    push!(parent(A), map(last, pairs)...)
    A
end
