#=
All that's left here is some faster replacements for things like findall(<=(3), range).
The ones in Base always return an Array, while these return ranges.
A messy collection, ideally to be replaced by this:
https://github.com/JuliaMath/IntervalSets.jl/issues/52#issuecomment-603767916

Replacements for findfirst(==(3), range) and findall(==(3), range) moved to lookup.jl.
=#

findindex(eq::Base.Fix2{typeof(<=),Int}, r::Base.OneTo{Int}) =
    eq.x < 1 ? Base.OneTo(0) :
    eq.x >= r.stop ? r :
    Base.OneTo(eq.x)

findindex(eq::Base.Fix2{typeof(<=)}, r::UnitRange{T}) where T =
    intersect(Base.OneTo(trunc(T,eq.x) - first(r) + 1), eachindex(r))

findindex(eq::Base.Fix2{typeof(<=)}, r::StepRange{T}) where T =
# findindex(eq::Base.Fix2{typeof(<=)}, r::AbstractRange{T}) where T =
    eq.x < r.start ? OneTo(0) :
    eq.x >= r.stop ? OneTo(length(r)) :
    OneTo(trunc(Int, div(eq.x - first(r), step(r))) + 1)

findindex(eq::Base.Fix2{typeof(<),Int}, r::Base.OneTo{Int}) =
    eq.x <= 1 ? Base.OneTo(0) :
    eq.x > r.stop ? r :
    Base.OneTo(eq.x - 1)

findindex(eq::Base.Fix2{typeof(<)}, r::UnitRange{T}) where T =
    intersect(Base.OneTo(trunc(T,eq.x - first(r))), eachindex(r))

# findindex(eq::Base.Fix2{typeof(<)}, r::StepRange{T}) where T =
#     Base.OneTo(trunc(Int, div(eq.x - first(r) - 1, step(r))) + 1)

findindex(eq::Base.Fix2{typeof(>=),Int}, r::Base.OneTo{Int}) =
    eq.x <= 1 ? UnitRange(r) :
    eq.x > r.stop ? (1:0) :
    (eq.x : r.stop)

findindex(eq::Base.Fix2{typeof(>=)}, r::UnitRange{T}) where T =
    intersect(UnitRange(trunc(T,eq.x) - first(r) + 1, length(r)), eachindex(r))

findindex(eq::Base.Fix2{typeof(>),Int}, r::Base.OneTo{Int}) =
    eq.x < 1 ? UnitRange(r) :
    eq.x >= r.stop ? (1:0) :
    (eq.x+1 : r.stop)

findindex(eq::Base.Fix2{typeof(>)}, r::OrdinalRange{T}) where T =
    intersect(UnitRange(trunc(T,eq.x) - first(r) + 2, length(r)), eachindex(r))

findindex(eq::Base.Fix2{typeof(>)}, r::StepRange{T}) where T =
# findindex(eq::Base.Fix2{typeof(>)}, r::AbstractRange{T}) where T =
    eq.x < r.start ? (1:length(r)) :
    eq.x >= r.stop ? (1:0) :
    UnitRange(trunc(Int, div(eq.x - first(r), step(r))) + 2, length(r))

