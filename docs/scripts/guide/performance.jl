# This file has some quick speed checks of AxisKeys functionality, and of other packages of similar
# or overlapping concerns. Plus generally a place to collect their various syntax, for comparison.


using AxisKeys, BenchmarkTools
# ## getkey vs getindex

mat = wrapdims(rand(3,4), 11:13, 21:24)
bothmat = wrapdims(mat.data, x=11:13, y=21:24)
bothmat2 = wrapdims(mat.data, x=collect(11:13), y=collect(21:24))


@btime $mat[3, 4];
@btime $mat(13, 24);

# for bothmat

@btime $bothmat[3,4];
@btime $bothmat[x=3, y=4];

# also 

@btime $bothmat(13, 24);
@btime $bothmat(x=13, y=24);

# for bothmat2

@btime $bothmat2(13, 24);

# ## with @inbounds
ind_collect(A) = [@inbounds(A[ijk...]) for ijk in Iterators.ProductIterator(axes(A))]
key_collect(A) = [@inbounds(A(vals...)) for vals in Iterators.ProductIterator(axiskeys(A))]

bigmat = wrapdims(rand(100,100), 1:100, 1:100);
bigmat2 = wrapdims(rand(100,100), collect(1:100), collect(1:100));


@btime ind_collect($(bigmat.data));
@btime ind_collect($bigmat);
@btime key_collect($bigmat);

# findfirst(..., vector) lookup

@btime key_collect($bigmat2);

# more `mat`

twomat = wrapdims(mat.data, x=[:a, :b, :c], y=21:24)

@btime $twomat(x=:a, y=24);

# and

@btime $twomat(24.0);
@btime $twomat(y=24.0);

# and

@btime view($twomat, :,3);

# ## Other packages

# ### OffsetArrays
using OffsetArrays
of1 = OffsetArray(rand(3,4), 11:13, 21:24)
#
@btime $of1[13,24];

bigoff = OffsetArray(bigmat.data, 1:100, 1:100);
# 
@btime ind_collect($bigoff);

# ### AxisArrays
using AxisArrays
ax1 = AxisArray(rand(3,4), 11:13, 21:24)
ax2 = AxisArray(rand(3,4), :x, :y)
#
@btime $ax1[3,4];
@btime $ax2[3,4];
@btime $ax2[Axis{:x}(3), Axis{:y}(4)];

#
@btime $ax1[atvalue(13), atvalue(24)];

bigax = AxisArray(bigmat.data, 1:100, 1:100);
bigax2 = AxisArray(bigmat.data, collect(1:100), collect(1:100));
ax_collect(A) = [@inbounds(A[atvalue(vals[1]), atvalue(vals[2])]) for vals in Iterators.ProductIterator(AxisArrays.axes(A))];

#
@btime ind_collect($bigax);
@btime ax_collect($bigax);
@btime ax_collect($bigax2); 

#

# ### NamedArrays
using NamedArrays

na1 = NamedArray(rand(3,4))

na2 = copy(na1);
setnames!(na2, ["a", "b", "c"], 1); na2
setnames!(na2, string.(1:4) .* "th", 2); na2 # must be strings, and all different

# 
@btime $na1[3,4];
@btime $na2["c",4];
@btime $na2["c","4th"];

#
# This lookup is via OrderedDict{String,Int64}
@btime $na2.dicts[2]["4th"];

#
na1.dimnames == (:A, :B)
# @btime na1[:A => 3, :B => 4] # error
@btime $na2[:A => "c", :B => "4th"];

#

# ### NamedDims
using NamedDims
nd1 = NamedDimsArray(rand(3,4), (:x, :y))

#
@btime $nd1[3,4];
@btime $nd1[x=3, y=4];  # fixed by https://github.com/invenia/NamedDims.jl/pull/84

# 

# ### DimensionalData
using DimensionalData
using DimensionalData: X, Y, @dim, ForwardOrdered

dd1 = DimArray(rand(3,4), (Dim{:x}(11:13), Dim{:y}(21:24)))
@dim dd_x; @dim dd_y
dd2 = DimArray(rand(3,4), (dd_x(11:13), dd_y(21:24)))
dd3 = DimArray(rand(3,4), (X(11:13), Y(21:24)))

#
@btime $dd1[3,4];
@btime $dd1[At(13), At(24)];

# StackOverflowError? no, was missing a (,) see https://github.com/rafaqz/DimensionalData.jl/issues/4
@btime $dd1[Dim{:x}(1), Dim{:y}(2)];

#
@btime $dd2[At(13), At(24)];
#@btime $dd2(dd_x <| At(13), dd_y <| At(24));

#
#@btime $dd3[X <| At(13), Y <| At(24)];
#@btime (m -> m[X <| At(13), Y <| At(24)])($dd3);

#

# ## Fast range lookup

const A = AxisKeys
const B = Base
using Base: OneTo

@btime B.findfirst(isequal(300), OneTo(1000));
@btime A.findfirst(isequal(300), OneTo(1000));

# 
@btime B.findfirst(isequal(300), 0:1000);
@btime A.findfirst(isequal(300), 0:1000);

#
@btime B.findall( <(10), OneTo(1000));
@btime A.findall( <(10), OneTo(1000));
@btime collect(A.findall( <(10), OneTo(1000)));

#
@btime B.findall( <(10), 1:1000);
@btime A.findall( <(10), 1:1000);
@btime collect(A.findall( <(10), 1:1000));

# 
B.findall( <(10), 1:1000) isa Vector

#
A.findall( <(10), 1:1000) isa OneTo

# ## Accelerated lookup

# ### AcceleratedArrays
using AcceleratedArrays

s1 = sort(rand(1:25, 100));
s2 = accelerate(s1, SortIndex);

# 
@btime findall(isequal(10), $s1);
@btime findall(isequal(10), $s2);

# 
w1 = wrapdims(1:100.0, x=s1);
w2 = wrapdims(1:100.0, x=s2);

# 
@btime $w1(==(10));
@btime $w2(==(10));
@btime $w1(10);

# no help for findfirst
@btime $w2(10);

#
r1 = collect(1:1000);
r2 = accelerate(r1, SortIndex);

# 
@btime findall(<(99), $r1);
@btime findall(<(99), $r2);

#

r0 = 1:1000

#
@btime A.findall(<(99), $r0);

#
bigmat3 = wrapdims(rand(100,100), accelerate(collect(1:100),SortIndex), accelerate(collect(1:100),SortIndex));

# 
@btime key_collect($bigmat3);

# ### DataStructures
using DataStructures
v1 = (1:100)[sortperm(rand(100))];

# 
@btime findfirst(isequal(10), $v1);

v2 = let
    d = OrderedDict{Int, Int}()
    for (i,k) in enumerate(v1)
        d[k] = i
    end
    d
end

# 
@btime $v2[10];

# 
v3 = accelerate(v1, UniqueHashIndex);

#
@btime findfirst(isequal(10), v3);

# ### CategoricalArrays
using CategoricalArrays

ca1 = wrapdims(rand(4), x = CategoricalArray(["a", "b", "a", "b"]))
ca1("a")
ca1(==("a"))

v4 = CategoricalArray(v1)
v4[1] == v1[1]

# 
@btime findfirst(isequal(10), $v4);

# the `end`.

