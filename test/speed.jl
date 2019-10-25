
using AxisRanges, BenchmarkTools # Julia 1.2 + macbook escape

mat = wrapdims(rand(3,4), 1:3, 1:4)
@btime $mat[3,4]  #  6.702 ns
@btime $mat(3,4)  # 10.344 ns

f1(m) = @inbounds m[3,4]
f2(m) = @inbounds m(3,4)
@btime f1($mat)
@btime f2($mat)

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

