julia> #===== Examples of how to use the AxisKeys package. =====#

(v1.3) pkg> add AxisKeys  # Now registered

julia> using AxisKeys, Random

julia> Random.seed!(42);

julia> KeyedArray((a=3, b=5, c=7)) # Using keys of a NamedTuple
1-dimensional KeyedArray(...) with keys:
↓   3-element Vector{Symbol}
And data, 3-element Array{Int64,1}:
 (:a)  3
 (:b)  5
 (:c)  7

julia> D = wrapdims(rand(Int8,5), iter = 10:10:50) # Convenience constructor
1-dimensional KeyedArray(NamedDimsArray(...)) with range:
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

julia> C = KeyedArray(rand(2,10) .+ (0:1), obs=["dog", "cat"], time=range(0, step=0.5, length=10))
2-dimensional KeyedArray(NamedDimsArray(...)) with ranges:
↓   obs ∈ 2-element Vector{String}
→   time ∈ 10-element StepRangeLen{Float64,...}
And data, 2×10 Array{Float64,2}:
           (0.0)       (0.5)       (1.0)       (1.5)       …  (3.5)        (4.0)       (4.5)
  ("dog")    0.160006    0.602298    0.383491    0.745181       0.0823367    0.452418    0.281987
  ("cat")    1.42296     1.36346     1.59291     1.26281        1.24468      1.76372     1.14364

julia> dimnames(C) # Works like size & axes, i.e. dimnames(C,2) == :time
(:obs, :time)

julia> axiskeys(C) # Likewise, axiskeys(C, :time) == 0:0.5:4.5
(["dog", "cat"], 0.0:0.5:4.5)

julia> axes(C) # Base.axes is untouched
(Base.OneTo(2), Base.OneTo(10))

julia> C[1,3]
0.3834911947029529

julia> C("dog", Index[3]) # Selector Index[i] lets you mix lookup and indexing
0.3834911947029529

julia> C(time=Near(1.1), obs="dog") # Selector Near(val) finds one closest index
0.3834911947029529

julia> C(!=("cat"), Index[end]) # Functions allowed as selectors, and Index[end] works
1-dimensional KeyedArray(NamedDimsArray(...)) with range:
↓   obs ∈ 1-element view(::Vector{String},...)
And data, 1-element view(::Array{Float64,2}, [1], 10) with eltype Float64:
 ("dog")  0.28198708251379423

julia> C(0.5) # Here 0.5 is unambiguous as types of ranges are distinct
1-dimensional KeyedArray(NamedDimsArray(...)) with range:
↓   obs ∈ 2-element Vector{String}
And data, 2-element view(::Array{Float64,2}, :, 2) with eltype Float64:
 ("dog")  0.602297580266383
 ("cat")  1.3634584219520556

julia> C * C' # Functions like adjoint and * work through wrappers
2-dimensional KeyedArray(NamedDimsArray(...)) with ranges:
↓   obs ∈ 2-element Vector{String}
→   obs ∈ 2-element Vector{String}
And data, 2×2 Array{Float64,2}:
           ("dog")   ("cat")
  ("dog")   1.92623   5.85958
  ("cat")   5.85958  21.8234

julia> ans("mouse")
ERROR: ArgumentError: key of type String is ambiguous, matches dimensions (1, 2)

julia> C("mouse")
ERROR: ArgumentError: could not find key "mouse" in vector ["dog", "cat"]

julia> for (i,t) in enumerate(C.time)
       t > 3 && println("at time $t, value cat = ", C[2,i])
       end
at time 3.5, value cat = 1.244682870516645
at time 4.0, value cat = 1.763719368415045
at time 4.5, value cat = 1.1436376769992096

julia> using Statistics

julia> mean(C, dims=:time) # Reduction functions should accept dimension names
2-dimensional KeyedArray(NamedDimsArray(...)) with ranges:
↓   obs ∈ 2-element Vector{String}
→   time ∈ 1-element OneTo{Int}
And data, 2×1 Array{Float64,2}:
           (1)
  ("dog")    0.3918636606806696
  ("cat")    1.4542825908906043

julia> map(sqrt, D) .* sqrt.(D) # map, broadcasting, and generators should work
1-dimensional KeyedArray(NamedDimsArray(...)) with range:
↓   iter ∈ 5-element StepRange{Int64,...}
And data, 5-element Array{Float64,1}:
 (10)  114.99999999999999
 (20)   99.0
 (30)    0.0
 (40)   57.0
 (50)   88.0

julia> vcat(D', zero(D'), similar(D'))
2-dimensional KeyedArray(NamedDimsArray(...)) with ranges:
↓   _ ∈ 3-element OneTo{Int}
→   iter ∈ 5-element StepRange{Int64,...}
And data, 3×5 Array{Int8,2}:
      (10)  (20)  (30)  (40)  (50)
 (1)   115    99     0    57    88
 (2)     0     0     0     0     0
 (3)    48   -44   -18     8     1

julia> F = wrapdims(rand(1:100, 5), 🔤 = 'a':'z') # ranges are adjusted if possible
┌ Warning: range 'a':1:'z' replaced by 'a':1:'e', to match size(A, 1) == 5
└ @ AxisKeys ~/.julia/dev/AxisKeys/src/wrap.jl:46
1-dimensional KeyedArray(NamedDimsArray(...)) with range:
↓   🔤 ∈ 5-element StepRange{Char,...}
And data, 5-element Array{Int64,1}:
 ('a')  16
 ('b')  87
 ('c')  49
 ('d')  91
 ('e')  44

julia> push!(F, 10^6) # push! also knows to extend 'a':'e' by one
1-dimensional KeyedArray(NamedDimsArray(...)) with range:
↓   🔤 ∈ 6-element StepRange{Char,...}
And data, 6-element Array{Int64,1}:
 ('a')       16
 ('b')       87
 ('c')       49
 ('d')       91
 ('e')       44
 ('f')  1000000

julia> using UniqueVectors # https://github.com/garrison/UniqueVectors.jl

julia> u = unique(rand(Int8, 100));

julia> H = wrapdims(rand(3,length(u),2), UniqueVector; # apply this type to all ranges
           row=[:a, :b, :c], col=u, page=["one", "two"])
3-dimensional KeyedArray(NamedDimsArray(...)) with ranges:
↓   row ∈ 3-element UniqueVector{Symbol}
→   col ∈ 81-element UniqueVector{Int8}
□   page ∈ 2-element UniqueVector{String}
And data, 3×81×2 Array{Float64,3}:
[:, :, 1] ~ (:, :, "one"):
        (-25)         (-96)         (0)         …  (69)          (-14)
  (:a)      0.293286      0.97221     0.857084        0.894496       0.994897
  (:b)      0.966373      0.112904    0.98633         0.0459311      0.393979
  (:c)      0.410052      0.69666     0.800045        0.524544       0.195882

[:, :, 2] ~ (:, :, "two"):
        (-25)         (-96)          (0)          …  (69)          (-14)
  (:a)      0.486264      0.111887     0.632189         0.0597532      0.493346
  (:b)      0.123933      0.988803     0.243089         0.701553       0.11737
  (:c)      0.850917      0.0495313    0.0470764        0.322251       0.642556

julia> H(:a, -14, "one") # uses the UniqueVector's fast lookup
0.9948971186701887

julia> using LazyStack # A package for concatenating arrays

julia> stack(:pre, n .* D for n in 1:10)
2-dimensional NamedDimsArray(KeyedArray(...)) with keys:
↓   iter ∈ 5-element StepRange{Int64,...}
→   pre ∈ 10-element OneTo{Int}
And data, 5×10 Array{Int64,2}:
       (1)  (2)  (3)  (4)  (5)  (6)  (7)  (8)   (9)  (10)
 (10)  115  230  345  460  575  690  805  920  1035  1150
 (20)   99  198  297  396  495  594  693  792   891   990
 (30)    0    0    0    0    0    0    0    0     0     0
 (40)   57  114  171  228  285  342  399  456   513   570
 (50)   88  176  264  352  440  528  616  704   792   880
