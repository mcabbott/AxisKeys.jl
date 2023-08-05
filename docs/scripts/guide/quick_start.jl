using AxisKeys, Random
Random.seed!(42);

# ## Using keys of a NamedTuple
KeyedArray((a=3, b=5, c=7))

# Convenience constructor
D = wrapdims(rand(Int8,5), iter = 10:10:50) .|> abs

# what is D?
D isa AbstractArray

# ## Square brackets index as usual
D[2] 

# ## Round brackets lookup by key
D(20) 

# ## range of keys
# The range of keys is property D.name
D.iter 

# ## Pretty printing of NamedDimsArray
E = wrapdims(rand(Int8, 2,3), :row, :col) 

# Fixing one index gives a slice
@view E[col=1] 

# ## size, axes & axiskeys
C = KeyedArray(rand(2,10) .+ (0:1), obs=["dog", "cat"], time=range(0, step=0.5, length=10))

# Works like `size` & `axes`, i.e. `dimnames(C,2) == :time`
dimnames(C) 

# Likewise, axiskeys(C, :time) == 0:0.5:4.5
axiskeys(C)

# Base.axes is untouched
axes(C)

# and
C[1,3]

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
