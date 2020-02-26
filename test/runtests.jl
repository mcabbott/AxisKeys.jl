using Test, AxisRanges, NamedDims
using Statistics, OffsetArrays, Tables, UniqueVectors, LazyStack

# AxisRanges.OUTER[] = :nda # changes behaviour of wrapdims

include("_basic.jl")

include("_functions.jl")

include("_notpiracy.jl")

@testset "offset" begin

    o = OffsetArray(rand(1:99, 5), -2:2)
    w = wrapdims(o, i='a':'e')
    @test ranges(w,1) isa OffsetArray
    @test w[i=-2] == w('a')

end
@testset "unique" begin

    u = wrapdims(rand(Int8,5,1), UniqueVector, [:a, :b, :c, :d, :e], nothing)
    @test ranges(u,1) isa UniqueVector
    @test u(:b) == u[2,:]

    n = wrapdims(rand(2,100), UniqueVector, x=nothing, y=rand(Int,100))
    @test ranges(n,1) isa UniqueVector
    k = ranges(n, :y)[7]
    @test n(y=k) == n[:,7]

end
@testset "tables" begin

    R = wrapdims(rand(2,3), 11:12, 21:23)
    N = wrapdims(rand(2,3), a=[11, 12], b=[21, 22, 23.0])

    @test keys(first(Tables.rows(R))) == (:dim_1, :dim_2, :value)
    @test keys(first(Tables.rows(N))) == (:a, :b, :value)

    @test Tables.columns(N).a == [11, 12, 11, 12, 11, 12]

end
@testset "stack" begin

    rin = [wrapdims(1:3, a='a':'c') for i=1:4]

    @test ranges(stack(rin), :a) == 'a':'c'
    @test ranges(stack(:b, rin...), :a) == 'a':'c' # tuple
    @test ranges(stack(z for z in rin), :a) == 'a':'c' # generator

    rout = wrapdims([[1,2], [3,4]], b=10:11)
    @test ranges(stack(rout), :b) == 10:11

    rboth = wrapdims(rin, b=10:13)
    @test ranges(stack(rboth), :a) == 'a':'c'
    @test ranges(stack(rboth), :b) == 10:13

    nts = [(i=i, j="j", k=33) for i=1:3]
    @test ranges(stack(nts), 1) == [:i, :j, :k]
    @test ranges(stack(:z, nts...), 1) == [:i, :j, :k]
    @test ranges(stack(n for n in nts), 1) == [:i, :j, :k]

end
