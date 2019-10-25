#===== Adding new functionality =====#

# https://github.com/JuliaLang/julia/pull/32968
filter(args...) = Base.filter(args...)
filter(f, xs::Tuple) = Base.afoldl((ys, x) -> f(x) ? (ys..., x) : ys, (), xs...)
filter(f, t::Base.Any16) = Tuple(filter(f, collect(t)))

# Treat Ref() like a 1-tuple in many contexts:
map(args...) = Base.map(args...)
map(f, r::Base.RefValue) = Ref(f(r[]))
map(f, r::Base.RefValue, t::Tuple) = Ref(f(r[], first(t)))

getindex(args...) = Base.getindex(args...)
getindex(r::Base.RefValue, i::Int) = i==1 ? r[] : error("nope")

filter(f, r::Base.RefValue) = f(r[]) ? Tuple(r) : ()

#===== Speeding up with same results =====#

# https://github.com/JuliaLang/julia/pull/33674
# Tuple(args...) = Base.Tuple(args...) # infinite loops?
# Tuple(r::Base.RefValue) = tuple(r[])
Base.Tuple(r::Base.RefValue) = tuple(r[])


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

findall(eq::Base.Fix2{typeof(<),Int}, r::Base.OneTo{Int}) =
    eq.x <= 1 ? Base.OneTo(0) :
    eq.x > r.stop ? r :
    Base.OneTo(eq.x - 1)

findall(eq::Base.Fix2{typeof(<)}, r::UnitRange{T}) where T =
    intersect(Base.OneTo(trunc(T,eq.x - first(r))), eachindex(r))

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
