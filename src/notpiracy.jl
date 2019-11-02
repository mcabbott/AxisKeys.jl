#===== Adding new functionality =====#

# https://github.com/JuliaLang/julia/pull/32968
filter(args...) = Base.filter(args...)
filter(f, xs::Tuple) = Base.afoldl((ys, x) -> f(x) ? (ys..., x) : ys, (), xs...)
filter(f, t::Base.Any16) = Tuple(filter(f, collect(t)))

# https://github.com/JuliaLang/julia/pull/29679 -> Compat.jl
if VERSION < v"1.1.0-DEV.472"
    isnothing(::Any) = false
    isnothing(::Nothing) = true
end

# https://github.com/JuliaLang/julia/pull/30496 -> Compat.jl
if VERSION < v"1.2.0-DEV.272"
    Base.@pure hasfield(::Type{T}, name::Symbol) where T =
        Base.fieldindex(T, name, false) > 0
    hasproperty(x, s::Symbol) = s in propertynames(x)
end

#===== Speeding up with same results =====#

# https://github.com/JuliaLang/julia/pull/33674
# Tuple(arg) = Base.Tuple(arg)
# Tuple(r::Base.RefValue) = tuple(getindex(r))
# Tuple(t::Tuple) = t # fix an ambiguity
# That causes a stackoverflow from check_ranges's Tuple(Array{AbstractArray...})
# which I can't sort out! Out solution is actual piracy:
# Base.Tuple(r::Base.RefValue) = tuple(r[])
# The other option is just to call it something else in ranges(A)
_Tuple(t::Tuple) = t
_Tuple(r::Base.RefValue) = tuple(getindex(r))

findfirst(args...) = Base.findfirst(args...)
findall(args...) = Base.findall(args...)

for equal in (isequal, Base.:(==))
    @eval begin

# findfirst returns always Int or Nothing

        findfirst(eq::Base.Fix2{typeof($equal),Int}, r::Base.OneTo{Int}) =
            1 <= eq.x <= r.stop ? eq.x : nothing

        findfirst(eq::Base.Fix2{typeof($equal)}, r::AbstractUnitRange) =
            first(r) <= eq.x <= last(r) ? 1+Int(eq.x - first(r)) : nothing

# findall returns a vector... which I would like to make a range?

        findall(eq::Base.Fix2{typeof($equal),Int}, r::Base.OneTo{Int}) =
            1 <= eq.x <= r.stop ? (eq.x:eq.x) : (1:0)

        function findall(eq::Base.Fix2{typeof($equal)}, r::AbstractUnitRange)
            val = 1 + Int(eq.x - first(r))
            first(r) <= eq.x <= last(r) ? (val:val) : (1:0)
        end

    end
end

findall(eq::Base.Fix2{typeof(<=),Int}, r::Base.OneTo{Int}) =
    eq.x < 1 ? Base.OneTo(0) :
    eq.x >= r.stop ? r :
    Base.OneTo(eq.x)

findall(eq::Base.Fix2{typeof(<=)}, r::UnitRange{T}) where T =
    intersect(Base.OneTo(trunc(T,eq.x) - first(r) + 1), eachindex(r))

findall(eq::Base.Fix2{typeof(<=)}, r::StepRange{T}) where T =
# findall(eq::Base.Fix2{typeof(<=)}, r::AbstractRange{T}) where T =
    eq.x < r.start ? OneTo(0) :
    eq.x >= r.stop ? OneTo(length(r)) :
    OneTo(trunc(Int, div(eq.x - first(r), step(r))) + 1)

findall(eq::Base.Fix2{typeof(<),Int}, r::Base.OneTo{Int}) =
    eq.x <= 1 ? Base.OneTo(0) :
    eq.x > r.stop ? r :
    Base.OneTo(eq.x - 1)

findall(eq::Base.Fix2{typeof(<)}, r::UnitRange{T}) where T =
    intersect(Base.OneTo(trunc(T,eq.x - first(r))), eachindex(r))

# findall(eq::Base.Fix2{typeof(<)}, r::StepRange{T}) where T =
#     Base.OneTo(trunc(Int, div(eq.x - first(r) - 1, step(r))) + 1)

findall(eq::Base.Fix2{typeof(>=),Int}, r::Base.OneTo{Int}) =
    eq.x <= 1 ? UnitRange(r) :
    eq.x > r.stop ? (1:0) :
    (eq.x : r.stop)

findall(eq::Base.Fix2{typeof(>=)}, r::UnitRange{T}) where T =
    intersect(UnitRange(trunc(T,eq.x) - first(r) + 1, length(r)), eachindex(r))

findall(eq::Base.Fix2{typeof(>),Int}, r::Base.OneTo{Int}) =
    eq.x < 1 ? UnitRange(r) :
    eq.x >= r.stop ? (1:0) :
    (eq.x+1 : r.stop)

findall(eq::Base.Fix2{typeof(>)}, r::OrdinalRange{T}) where T =
    intersect(UnitRange(trunc(T,eq.x) - first(r) + 2, length(r)), eachindex(r))

findall(eq::Base.Fix2{typeof(>)}, r::StepRange{T}) where T =
# findall(eq::Base.Fix2{typeof(>)}, r::AbstractRange{T}) where T =
    eq.x < r.start ? (1:length(r)) :
    eq.x >= r.stop ? (1:0) :
    UnitRange(trunc(Int, div(eq.x - first(r), step(r))) + 2, length(r))

