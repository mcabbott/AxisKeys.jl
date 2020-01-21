julia> #===== Examples of how to use the AxisArrays package. =====#

(v1.3) pkg> add https://github.com/mcabbott/AxisRanges.jl # Not a registered package

julia> using AxisRanges, Random

julia> Random.seed!(42);

julia> D = wrapdims(rand(Int8,5), iter = 10:10:50) # Convenience constructor
1-dimensional RangeArray(NamedDimsArray(...)) with range:
↓   iter ∈ 5-element StepRange{Int64,...}
And data, 5-element Array{Int8,1}:
 (10)  115
 (20)   99
 (30)    0
 (40)   57
 (50)   88

julia> D isa AbstractArray
true

julia> D[2] # Square brackets index as usual
99

julia> D(20) # Round brackets lookup by key
99

julia> D.iter # The range of keys is property D.name
10:10:50

julia> E = wrapdims(rand(Int8, 2,3), :row, :col) # Pretty printing of NamedDimsArray
2×3 NamedDimsArray(::Array{Int8,2}, (:row, :col)):
       → col
↓ row  -105   76    52
          3  -27  -112

julia> @view E[col=1] # Fixing one index gives a slice
2-element NamedDimsArray(view(::Array{Int8,2}, :, 1), (:row,)):
↓ row  -105
          3

julia> C = wrapdims(rand(2,10) .+ (0:1), obs=["dog", "cat"], time=range(0, step=0.5, length=10))
2-dimensional RangeArray(NamedDimsArray(...)) with ranges:
↓   obs ∈ 2-element Vector{String}
→   time ∈ 10-element StepRangeLen{Float64,...}
And data, 2×10 Array{Float64,2}:
           (0.0)       (0.5)       (1.0)       (1.5)       …  (3.5)        (4.0)       (4.5)
  ("dog")    0.160006    0.602298    0.383491    0.745181       0.0823367    0.452418    0.281987
  ("cat")    1.42296     1.36346     1.59291     1.26281        1.24468      1.76372     1.14364

julia> names(C) # Works like size & axes, i.e. names(C,2) == :time
(:obs, :time)

julia> ranges(C) # Likewise, ranges(C, :time) == 0:0.5:4.5
(["dog", "cat"], 0.0:0.5:4.5)

julia> C[1,3]
0.3834911947029529

julia> C("dog", Index[3]) # Selector Index[i] lets you mix lookup and indexing
0.3834911947029529

julia> C(time=Near(1.1), obs="dog") # Selector Near(val) finds one closest index
0.3834911947029529

julia> C(!=("cat"), Index[end]) # Functions allowed as selectors, and Index[end] works
1-dimensional RangeArray(NamedDimsArray(...)) with range:
↓   obs ∈ 1-element view(::Vector{String},...)
And data, 1-element view(::Array{Float64,2}, [1], 10) with eltype Float64:
 ("dog")  0.28198708251379423

julia> C(0.5) # Here 0.5 is unambiguous as types of ranges are distinct
1-dimensional RangeArray(NamedDimsArray(...)) with range:
↓   obs ∈ 2-element Vector{String}
And data, 2-element view(::Array{Float64,2}, :, 2) with eltype Float64:
 ("dog")  0.602297580266383
 ("cat")  1.3634584219520556

julia> C * C' # Functions like adjoint and * work through wrappers
2-dimensional RangeArray(NamedDimsArray(...)) with ranges:
↓   obs ∈ 2-element Vector{String}
→   obs ∈ 2-element Vector{String}
And data, 2×2 Array{Float64,2}:
           ("dog")   ("cat")
  ("dog")   1.92623   5.85958
  ("cat")   5.85958  21.8234

julia> ans("mouse")
ERROR: key of type String is ambiguous, matches dimensions (1, 2)

julia> C("mouse")
ERROR: could not find key "mouse" in range ["dog", "cat"]

julia> using Statistics

julia> mean(C, dims=:time) # Reduction functions should accept dimension names
2-dimensional RangeArray(NamedDimsArray(...)) with ranges:
↓   obs ∈ 2-element Vector{String}
→   time ∈ 1-element OneTo{Int}
And data, 2×1 Array{Float64,2}:
           (1)
  ("dog")    0.3918636606806696
  ("cat")    1.4542825908906043

julia> F = wrapdims(rand(1:100, 5), 🔤 = 'a':'z') # ranges are adjusted if possible
1-dimensional RangeArray(NamedDimsArray(...)) with range:
↓   🔤 ∈ 5-element StepRange{Char,...}
And data, 5-element Array{Int64,1}:
 ('a')  16
 ('b')  87
 ('c')  49
 ('d')  91
 ('e')  44

julia> push!(F, 10^6) # push! also knows to extend 'a':'e' by one
1-dimensional RangeArray(NamedDimsArray(...)) with range:
↓   🔤 ∈ 6-element StepRange{Char,...}
And data, 6-element Array{Int64,1}:
 ('a')       16
 ('b')       87
 ('c')       49
 ('d')       91
 ('e')       44
 ('f')  1000000

