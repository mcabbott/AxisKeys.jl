
using AxisRanges, BenchmarkTools # Julia 1.2 + macbook escape

#===== getkey vs getindex =====#

mat = wrapdims(rand(3,4), 11:13, 21:24)
bothmat = wrapdims(mat.data, x=11:13, y=21:24)
bothmat2 = wrapdims(mat.data, x=collect(11:13), y=collect(21:24))

@btime $mat[3, 4]    # 4.199 ns
@btime $mat(13, 24)  # 5.870 ns

@btime $bothmat[3,4]        # 4.202 ns
@btime $bothmat[x=3, y=4]   # 41.050 ns (2 allocations: 64 bytes)
@btime $bothmat(13, 24)     # 5.874 ns
@btime $bothmat(x=13, y=24) # 43.302 ns (2 allocations: 64 bytes)
@btime $bothmat2(13, 24)    # 18.949 ns

ind_collect(A) = [@inbounds(A[ijk...]) for ijk in Iterators.ProductIterator(axes(A))]
key_collect(A) = [@inbounds(A(vals...)) for vals in Iterators.ProductIterator(ranges(A))]

bigmat = wrapdims(rand(100,100), 1:100, 1:100);
bigmat2 = wrapdims(rand(100,100), collect(1:100), collect(1:100));

@btime ind_collect($(bigmat.data)); #  8.811 μs (4 allocations: 78.25 KiB)
@btime ind_collect($bigmat);        # 11.525 μs (4 allocations: 78.25 KiB)
@btime key_collect($bigmat);        # 25.933 μs (4 allocations: 78.27 KiB)
@btime key_collect($bigmat2);      # 697.077 μs (5 allocations: 78.27 KiB)

#===== other packages =====#

using OffsetArrays

of1 = OffsetArray(rand(3,4), 11:13, 21:24)

@btime $of1[13,24] # 3.652 ns

bigoff = OffsetArray(bigmat.data, 1:100, 1:100);
@btime ind_collect($bigoff);        # 15.372 μs (5 allocations: 78.30 KiB)

using AxisArrays

ax1 = AxisArray(rand(3,4), 11:13, 21:24)
ax2 = AxisArray(rand(3,4), :x, :y)

@btime $ax1[3,4] # 1.421 ns
@btime $ax2[3,4] # 1.421 ns
@btime $ax2[Axis{:x}(3), Axis{:y}(4)] # 1.696 ns

@btime $ax1[atvalue(13), atvalue(24)] # 21.348 ns

bigax = AxisArray(bigmat.data, 1:100, 1:100);
bigax2 = AxisArray(bigmat.data, collect(1:100), collect(1:100));
ax_collect(A) = [@inbounds(A[atvalue(vals[1]), atvalue(vals[2])]) for vals in Iterators.ProductIterator(AxisArrays.axes(A))]
@btime ind_collect($bigax);        # 9.946 μs (4 allocations: 78.25 KiB)
@btime ax_collect($bigax);         # 212.160 μs (6 allocations: 78.34 KiB)
@btime ax_collect($bigax2);        # 511.157 μs (5 allocations: 78.27 KiB)

using NamedDims

na1 = NamedDimsArray(rand(3,4), (:x, :y))

@btime $na1[3,4]       #   1.421 ns
@btime $na1[x=3, y=4]  # 222.721 ns (6 allocations: 192 bytes)
                     # -> 40.467 ns (2 allocations: 64 bytes) with PR#76

using DimensionalData
using DimensionalData: X, Y, @dim, Forward

dd1 = DimensionalArray(rand(3,4), Dim{:x}(11:13), Dim{:y}(21:24))
@dim dd_x; @dim dd_y
dd2 = DimensionalArray(rand(3,4), (dd_x(11:13), dd_y(21:24)))
dd3 = DimensionalArray(rand(3,4), (X(11:13), Y(21:24)))

@btime $dd1[3,4] # 1.421 ns
# @btime $dd1[At(13), At(24)] # StackOverflowError?
# dd1[Dim{:x}(1), Dim{:y}(2)] # StackOverflowError?

@btime $dd2[At(13), At(24)] # 23.394 ns
@btime $dd2[dd_x <| At(13), dd_y <| At(24)] # 23.172 ns

@btime $dd3[X <| At(13), Y <| At(24)] # 23.256 ns
@btime (m -> m[X <| At(13), Y <| At(24)])($dd3) # 23.396 ns

using AbstractIndices # https://github.com/Tokazama/AbstractIndices.jl

ai1 = IndicesArray(rand(3,4), 11:13, 21:24)
ai2 = IndicesArray(rand(3,4); x=11:13, y=21:24)
ai3 = IndicesArray(rand(3,4), 11:13.0, 21:24.0)

# ai1[3,4] # all errors?
# ai1[13,24]
# ai2[x=13,y=24]
@btime $ai3[13.0, 24.0] # 31.437 ns

#===== fast range lookup =====#

const A = AxisRanges
const B = Base
using Base: OneTo

@btime B.findfirst(isequal(300), OneTo(1000)) #  173.225 ns
@btime A.findfirst(isequal(300), OneTo(1000)) #  0.029 ns

@btime B.findfirst(isequal(300), 0:1000)      #  90.410 ns
@btime A.findfirst(isequal(300), 0:1000)      #   0.029 ns

@btime B.findall( <(10), OneTo(1000));        # 742.162 ns
@btime A.findall( <(10), OneTo(1000));        #   0.029 ns
@btime collect(A.findall( <(10), OneTo(1000)));# 28.855 ns

@btime B.findall( <(10), 1:1000);             # 890.300 ns
@btime A.findall( <(10), 1:1000);             #   0.029 ns
@btime collect(A.findall( <(10), 1:1000));    #  28.888 ns

B.findall( <(10), 1:1000) isa Vector
A.findall( <(10), 1:1000) isa OneTo

#===== AcceleratedArrays =====#

using AcceleratedArrays

s1 = sort(rand(1:25, 100));
s2 = accelerate(s1, SortIndex);
@btime findall(isequal(10), $s1)  # 176.629 ns (6 allocations: 288 bytes)
@btime findall(isequal(10), $s2)  #  52.173 ns (3 allocations: 176 bytes)

w1 = wrapdims(1:100.0, x=s1);
w2 = wrapdims(1:100.0, x=s2);
@btime $w1(All(10))       # 538.672 ns (21 allocations: 976 bytes)
@btime $w2(All(10))       # 397.184 ns (18 allocations: 864 bytes)

@btime $w1(10) # 98.399 ns (4 allocations: 256 bytes)
@btime $w2(10) # no help for findfirst

r1 = collect(1:1000);
r2 = accelerate(r1, SortIndex);
@btime findall(<(99), $r1);   # 1.426 μs (11 allocations: 2.36 KiB)
@btime findall(<(99), $r2);   # 1.688 μs (11 allocations: 2.36 KiB)
r0 = 1:1000
@btime A.findall(<(99), $r0); # 0.029 ns (0 allocations: 0 bytes)

bigmat3 = wrapdims(rand(100,100), accelerate(collect(1:100),SortIndex), accelerate(collect(1:100),SortIndex));
@btime key_collect($bigmat3);      # 765.999 μs (5 allocations: 78.27 KiB) -- slower, findfirst.
