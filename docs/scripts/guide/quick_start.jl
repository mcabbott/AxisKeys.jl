using AxisKeys, Random
using OffsetArrays
Random.seed!(42);

# ## Construction

# ### nested pair of wrappers
KeyedArray(rand(Int8, 2,10), ([:a, :b], 10:10:100))

# A nested pair of wrappers can be constructed with keywords for names, and everything should work
# the same way in either order:

KeyedArray(rand(Int8, 2,10), row=[:a, :b], col=10:10:100)

#
A = NamedDimsArray(rand(Int8, 2,10), row=[:a, :b], col=10:10:100)

# Calling `AxisKeys.keyless(A)` removes the `KeyedArray` wrapper, if any, and `NamedDims.unname(A)`
# similarly removes the names (regardless of which is outermost). 

AxisKeys.keyless(A)

# ### wrapdims, Pretty printing of NamedDimsArray

# There is another more "casual" constructor, via the function `wrapdims`. This does a bit
# more checking of inputs, and will adjust the length of ranges of keys if it can, and will
# fix indexing offsets if needed to match the array. The resulting order of wrappers
# is controlled by `AxisKeys.nameouter()=false.`

wrapdims(rand(Int8, 10), alpha='a':'z')

#
wrapdims(OffsetArray(rand(Int8, 10),-1), iter=10:10:100)


# ### Using keys of a NamedTuple
KeyedArray((a=3, b=5, c=7))

# ## Selections

# Indexing still works directly on the underlying array, 
# and keyword indexing (of a nested pair) works exactly as for a `NamedDimsArray`.
# But in addition, it is possible to pick out elements based on the keys,
# which for clarity I will call lookup. This is written with round brackets:

# | Dimension `d` | Indexing: `i ∈ axes(A,d)` | Lookup: `key ∈ axiskeys(A,d)` |
# |--------------------|---------------------|---------------------|
# | by position        | `A[1,2,:]`          | `A(:left, 15.5, :)` |
# | by name            | `A[iter=1]`         | `A(iter=31)`        |
# | by type            |  --                 | `B = A(:left)`      |

# Convenience constructor
D = wrapdims(rand(Int8,5), iter = 10:10:50) .|> abs

# what is D?
D isa AbstractArray

# ### Square brackets index as usual
D[2] 

# ### Round brackets lookup by key
D(20) 

# range of keys
# The range of keys is property D.name
D.iter 


# When using dimension names, fixing only some of them will return a slice, such as `B = A[channel=1]`.
# You may also give just one key, provided its type matches those of just one dimension,
# such as `B = A(:left)` where the key is a Symbol.

# Note that indexing is the primary way to access the data. Lookup calls for example
# `i = findfirst(axiskeys(A,1), :left)` to convert keys to indices, thus will always be slower.
# If you want this to be the primary mode of access, then you may want a dictionary,
# possibly [`Dictionaries.jl`](https://github.com/andyferris/Dictionaries.jl).

# There are also a number of special selectors, which work like this:

# |                 | Indexing         | Lookup                  |         |
# |-----------------|------------------|-------------------------|---------|
# | one nearest     | `B[time = 3]`    | `B(time = Near(17.0))`  | vector  |
# | all in a range  | `B[2:5, :]`      | `B(Interval(14,25), :)` | matrix  |
# | all matching    | `B[3:end, Not(3)]` | `B(>(17), !=(33))`    | matrix  |
# | mixture         | `B[1, Key(33)]`  | `B(Index[1], 33)`       | scalar  |
# | non-scalar      | `B[iter=[1, 3]]` | `B(iter=[31, 33])`      | matrix  |

# Here `Interval(13,18)` can also be written `13..18`, it's from [`IntervalSets.jl`](https://github.com/JuliaMath/IntervalSets.jl). 
# Any functions can be used to select keys, including lambdas: `B(time = t -> 0<t<17)`. 
# You may give just one `::Base.Fix2` function 
# (such as `<=(18)` or `==(20)`) provided its argument type matches the keys of one dimension.
# An interval or a function always selects via `findall`, 
# i.e. it does not drop a dimension, even if there is exactly one match. 

# While this table shows lookup selectors inside `B(...)`, they can in fact all be 
# used inside `B[...]`, not just `Key(k)` as shown. They still refer to keys not indices!
# (This will not select dimension based on type, i.e. `A[Key(:left)]` is an error.)
# You may also write `Index[end]` but not `Index[end-1]`.

# By default lookup returns a view, while indexing returns a copy unless you add `@views`. 
# This means that you can write into the array with `B(time = <=(18)) .= 0`.
# For scalar output, you cannot of course write `B(13.0, 33) = 0` 
# as this parsed as a function definition, but you can write `B[Key(13.0), Key(33)] = 0`,
# or else `B(13.0, 33, :) .= 0` as a trailing colon makes a zero-dimensional view.

# ## @view

E = wrapdims(rand(Int8, 2,3), :row, :col) 

# Fixing one index gives a slice
@view E[col=1] 

# ## Functions, size, axes & axiskeys

# The function `axes(A)` returns (a tuple of vectors of) indices as usual, 
# and `axiskeys(A)` similarly returns (a tuple of vectors of) keys.
# If the array has names, then `dimnames(A)` returns them.
# These functions work like `size(A, d) = size(A, name)` to get just one.

C = KeyedArray(rand(2,10) .+ (0:1), obs=["dog", "cat"], time=range(0, step=0.5, length=10))

# Works like `size` & `axes`, i.e. `dimnames(C,2) == :time`
dimnames(C) 

# Likewise, axiskeys(C, :time) == 0:0.5:4.5
axiskeys(C)

# Base.axes is untouched
axes(C)

# and
C[1,3]

# The following things should work:
# !!! info "more supported functions"
#       * Broadcasting `log.(A)` and `map(log, A)`, as well as comprehensions 
#       `[log(x) for x in A]` should all work. 
#
#       * Transpose etc, `permutedims`, `mapslices`.
#
#       * Concatenation `hcat(B, B .+ 100)` works. 
#       Note that the keys along the glued direction may not be unique afterwards.
#
#       * Reductions like `sum(A; dims=:channel)` can use dimension names. 
#       Likewise `prod`, `mean` etc., and `dropdims`.
#
#       * Sorting: `sort` and `sortslices` permute keys & data by the array, 
#       while a new function `sortkeys` goes by the keys.
#       `reverse` similarly re-orders keys to match data.
#
#       * Some linear algebra functions like `*` and `\` will work. 
#
#       * Getproperty returns the key vector, to allow things like
#       `for (i,t) in enumerate(A.time); fun(val = A[i,:], time = t); ...`.
#
#       * Vectors support `push!(V, val)`, which will try to extend the key vector. 
#       There is also a method `push!(V, key => val)` which pushes in a new key. 
#
#       To allow for this limited mutability, `V.keys isa Ref` for vectors, 
#       while `A.keys isa Tuple` for matrices & higher. But `axiskeys(A)` always returns a tuple.
#
#       * Named tuples can be converted to and from keyed vectors,
#       with `collect(keys(nt)) == Symbol.(axiskeys(V),1)`
#
#       * The [Tables.jl](https://github.com/JuliaData/Tables.jl) interface is supported,
#       with `wrapdims(df, :val, :x, :y)` creating a matrix from 3 columns.
#
#       * Some [StatsBase.jl](https://github.com/JuliaStats/StatsBase.jl) and 
#       [CovarianceEstimation.jl](https://github.com/mateuszbaran/CovarianceEstimation.jl) functions 
#       are supported. ([PR#28](https://github.com/mcabbott/AxisKeys.jl/pull/28).)
#
#       * [FFTW](https://github.com/JuliaMath/FFTW.jl)`.fft` transforms the keys; 
#       if these are times such as [Unitful](https://github.com/PainterQubits/Unitful.jl)`.s` 
#       then the results are fequency labels. ([PR#15](https://github.com/mcabbott/AxisKeys.jl/pull/15).)
#
#       * [LazyStack](https://github.com/mcabbott/LazyStack.jl)`.stack` understands names and keys.
#       Stacks of named tuples like `stack((a=i, b=i^2) for i=1:5)` create a matrix with `[:a, :b]`.
#
#       * [NamedPlus](https://github.com/mcabbott/NamedPlus.jl) has a macro which works on comprehensions:
#       `@named [n^pow for n=1:10, pow=0:2:4]` has names and keys.
#

# ## Selector, mixing lookup and indexing

# Selector Index[i] lets you mix lookup and indexing
C("dog", Index[3]) 

# Selector `Near(val)` finds one closest index
C(time=Near(1.1), obs="dog") 

# Functions allowed as selectors, and `Index[end]` works
C(!=("cat"), Index[end])

# Here 0.5 is unambiguous as types of ranges are distinct
C(0.5) 

# Functions like adjoint and * work through wrappers
C * C' 

# is there a `mouse`?
try
    C("mouse")
catch err
    showerror(stderr, err)
end


# get time index

for (i,t) in enumerate(C.time)
    t > 3 && println("at time $t, value cat = ", C[2,i])
end

# ## Statistics

using Statistics
# Reduction functions should accept dimension names
mean(C, dims=:time) 

# map, broadcasting, and generators should work

map(sqrt, D) .* sqrt.(D)

# vcat
vcat(D', zero(D'), similar(D'))

# ranges are adjusted if possible

F = wrapdims(rand(1:100, 5), 🔤 = 'a':'z') 

# push! also knows to extend 'a':'e' by one
push!(F, 10^6) 

using UniqueVectors
using Random
Random.seed!(123)
u = unique(rand(Int8, 100))

 # apply this type to all ranges
H = wrapdims(rand(3,length(u),2), UniqueVector;
           row=[:a, :b, :c], col=u, page=["one", "two"])

# uses the UniqueVector's fast lookup
H(:a, -14, "one")

# ## Concatenating arrays

# A package for concatenating arrays
using LazyStack 
LazyStack.stack(:pre, n .* D for n in 1:10)
