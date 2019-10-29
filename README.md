# AxisRanges.jl

[![Build Status](https://travis-ci.org/mcabbott/AxisRanges.jl.svg?branch=master)](https://travis-ci.org/mcabbott/AxisRanges.jl)

This package defines a wrapper which, alongside any array, stores an extra "range" for each dimension.
This may be useful to store perhaps actual times of measurements, 
or some strings labelling columns, etc. 
These will be propagated through many operations on arrays. 

They can also be used to look up elements: 
While indexing `A[i]` expects an integer `i ∈ axes(A,1)` as usual, 
`A(t)` instead looks up `t ∈ ranges(A,1)`. 

The package aims to work well with [NamedDims.jl](https://github.com/invenia/NamedDims.jl), which attaches names to dimensions. 
(These names are a tuple of symbols, like those of a `NamedTuple`.)
There's a convenience function `wrapdims` which constructs any combination:
```julia
A = wrapdims(rand(10), 10:10:100)    # RangeArray
B = wrapdims(rand(2,3), :row, :col)  # NamedDimsArray
C = wrapdims(rand(2,10), obs=["dog", "cat"], time=range(0, step=0.5, length=10)) # both
```
With both, we can write `C[time=1, obs=2]` to index by number, 
and `C(time=3.5)` by the range value. 
This should work for either a `RangeArray{...,NamedDimsArray}` or the reverse.

The ranges themselves may be any `AbstractVector`s, and `A(20.0)` simply looks up 
`i = findfirst(isequal(20.0), ranges(A,1))` before returning `A[i]`.
Instead of a single value you may also give a function, for instance `A(<(35))`
looks up `is = findall(t -> t<35, ranges(A,1))` and returns the vector `A[is]`,
with its range trimmed to match. You may also give one few special selectors:  
```julia
A(Near(12.5))           # the one nearest element
C(time = Between(1,3))  # matrix with all times in this range
C("dog", Index[3])      # mix of range and integer indexing
```

While no special types are provided for these ranges,
you could use for instance the arrays from [AcceleratedArrays.jl](https://github.com/andyferris/AcceleratedArrays.jl) 
whose elements are hashed for fast lookup. 

When a dimension’s range is a Julia range, then there are some fast overloads
for things like `findall(<=(42), 10:10:100)`. For vectors, `push!(A, 0.72)` should also
figure out how to extend the range with more steps.

<!--
The larger goal is roughly to divide up the functionality of [AxisArrays.jl](https://github.com/JuliaArrays/AxisArrays.jl)
among smaller packages.
-->
Broadcasting does not work yet, sadly.

It's also slow at the moment -- see [test/speed.jl](test/speed.jl) for some numbers.

And finally, there’s no obvious notation for `setkey!(A, value, key)`.
One idea is to make selectors could work backwards, allowing `A[Key(key)] = val`.
Or a macro `@set A(key) = val`.
