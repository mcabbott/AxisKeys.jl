# AxisRanges.jl

[![Build Status](https://travis-ci.org/mcabbott/AxisRanges.jl.svg?branch=master)](https://travis-ci.org/mcabbott/AxisRanges.jl)

This package defines a thin wrapper which, alongside any array, stores an extra "range" 
for each dimension. This may be useful to store perhaps actual times of measurements, 
or some strings labeling columns, etc. These will be propagated through many 
operations on arrays, including broadcasting, `map` and comprehensions.

They can also be used to look up elements: While indexing `A[i]` expects an integer 
`i ∈ axes(A,1)`  as usual, `A(t)` instead looks up `t ∈ ranges(A,1)`. 

The package works closely with [NamedDims.jl](https://github.com/invenia/NamedDims.jl), 
which attaches names to dimensions. (These names are a tuple of symbols, like those of 
a `NamedTuple`.) There's a convenience function `wrapdims` which constructs any combination:
```julia
A = wrapdims(rand(10), 10:10:100)    # RangeArray
B = wrapdims(rand(2,3), :row, :col)  # NamedDimsArray
C = wrapdims(rand(2,10), obs=["dog", "cat"], time=range(0, step=0.5, length=10)) # both
```
With both, we can write `C[time=1, obs=2]` to index by number, 
and `C(time=3.5)` to lookup this key in the range. 
Everything should work for either a `RangeArray{...,NamedDimsArray}` or the reverse.

The ranges themselves may be any `AbstractVector`s, and `A(20.0)` simply looks up 
`i = findfirst(isequal(20.0), ranges(A,1))` before returning `A[i]`.
No special types are provided for these ranges, but those from say
[UniqueVectors.jl](https://github.com/garrison/UniqueVectors.jl)
or [AcceleratedArrays.jl](https://github.com/andyferris/AcceleratedArrays.jl) 
or [CategoricalArrays.jl](https://github.com/JuliaData/CategoricalArrays.jl) should work fine.
To apply such a type to all ranges, you may write:
```julia
D = wrapdims(rand(1000), UniqueVector, rand(Int, 1000))
```
Then `D(n)` here will use the fast lookup from UniqueVectors.jl (about 60x faster).

Instead of looking up a single value, you may also give a function. For instance `A(<(35))`
looks up `is = findall(t -> t<35, ranges(A,1))` and returns the vector `view(A, is)`,
with its range trimmed to match. You may also give one of a few special selectors:
```julia
A(Near(12.5))           # the one nearest element
C(time=Interval(1,3))   # matrix with all times in 1..3
C("dog", Index[3])      # mix of range and integer indexing, allows Index[end]
C(!=("dog"))            # unambigous as only range(C,1) contains strings
```
When a dimension’s range is a Julia `AbstractRange`, then this package provides some faster 
overloads for things like `findall(<=(42), 10:10:100)`. 
And for vectors, `push!(A, 0.72)` should also figure out how to extend the range with more steps.

<!--
The larger goal is roughly to divide up the functionality of [AxisArrays.jl](https://github.com/JuliaArrays/AxisArrays.jl)
among smaller packages.
-->
* See [docs/repl.jl](docs/repl.jl) for some usage examples, showing pretty printing. 
  And see [docs/speed.jl](docs/speed.jl) for some numbers, and comparisons to other packages.

* It tries to support the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface,
  for example `DataFrame(Tables.rows(C))` has column names `[:obs, :time, :value]`.

* There’s no very obvious notation for `setkey!(A, value, key)`.
  One idea is to make selectors could work backwards, allowing `A[Key(key)] = val`.
  For now, you can write `C("dog") .= 1:10` since it's a view.

* `Index[end]` works, perhaps [EndpointRanges.jl](https://github.com/JuliaArrays/EndpointRanges.jl) is the way to let `Index[end-1]` work.

* You can extract ranges via getproperty, to write  `for (i,t) in enumerate(C.time)` etc. 
  (Stolen from [this PR](https://github.com/JuliaArrays/AxisArrays.jl/pull/152).)

Links to the zoo of similar packages (also see [docs/speed.jl](docs/speed.jl)):

* Anciet, pre-1.0: [AxisArrays](https://github.com/JuliaArrays/AxisArrays.jl) (name + range as an `Axis` object, indexing vs. lookup according to type), 
  [NamedArrays](https://github.com/davidavdav/NamedArrays.jl) (also prints nicely, not type-stable?).
  Also perhaps [AxisArrayPlots](https://github.com/jw3126/AxisArrayPlots.jl) (recipes),
  [LabelledArrays](https://github.com/JuliaDiffEq/LabelledArrays.jl) (names for elements, not dimensions).

* New, or in progress: [NamedDims](https://github.com/invenia/NamedDims.jl) (just names, used above), 
  [DimensionalData](https://github.com/rafaqz/DimensionalData.jl) (most similar to AxisArrays),
  [IndexedDims](https://github.com/invenia/IndexedDims.jl) (likewise adds ranges onto names from `NamedDims`),
  [NamedPlus](https://github.com/mcabbott/NamedPlus.jl) (adds many features for `NamedDims` names),
  [Dictionaries](https://github.com/andyferris/Dictionaries.jl) (fast lookup only, no indexing, not `<: AbstractArray`).

* Discussion: [AxisArraysFuture](https://github.com/JuliaCollections/AxisArraysFuture/issues/1),
  [AxisArrays#84](https://github.com/JuliaArrays/AxisArrays.jl/issues/84).



