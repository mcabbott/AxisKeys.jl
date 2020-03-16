using Test, AxisKeys
using OffsetArrays, Tables, UniqueVectors, LazyStack

@testset "offset" begin

    o = OffsetArray(rand(1:99, 5), -2:2)
    w = wrapdims(o, i='a':'e')
    @test axiskeys(w,1) isa OffsetArray
    @test w[i=-2] == w('a')

end
@testset "unique" begin

    u = wrapdims(rand(Int8,5,1), UniqueVector, [:a, :b, :c, :d, :e], nothing)
    @test axiskeys(u,1) isa UniqueVector
    @test u(:b) == u[2,:]

    n = wrapdims(rand(2,100), UniqueVector, x=nothing, y=rand(Int,100))
    @test axiskeys(n,1) isa UniqueVector
    k = axiskeys(n, :y)[7]
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

    @test axiskeys(stack(rin), :a) == 'a':'c'
    @test axiskeys(stack(:b, rin...), :a) == 'a':'c' # tuple
    @test axiskeys(stack(z for z in rin), :a) == 'a':'c' # generator

    rout = wrapdims([[1,2], [3,4]], b=10:11)
    @test axiskeys(stack(rout), :b) == 10:11

    rboth = wrapdims(rin, b=10:13)
    @test axiskeys(stack(rboth), :a) == 'a':'c'
    @test axiskeys(stack(rboth), :b) == 10:13

    nts = [(i=i, j="j", k=33) for i=1:3]
    @test axiskeys(stack(nts), 1) == [:i, :j, :k]
    @test axiskeys(stack(:z, nts...), 1) == [:i, :j, :k]
    @test axiskeys(stack(n for n in nts), 1) == [:i, :j, :k]

end
