
M = wrapdims(rand(Int8, 3,4), r='a':'c', c=2:5)
V = wrapdims(rand(1:99, 10), v=10:10:100)

@testset "dims" begin

    # reductions
    M1 = sum(M, dims=1)
    @test ranges(M1, 1) === Base.OneTo(1)

    M2 = prod(M, dims=:c)
    @test ranges(M2) == ('a':'c', Base.OneTo(1))

    # dropdims
    @test ranges(dropdims(M1, dims=1)) == (2:5,)
    @test ranges(dropdims(M2, dims=:c)) == ('a':'c',)

    M3 = dropdims(M2, dims=:c)
    @test names(M3) == (:r,)

    # permutedims
    @test size(permutedims(M)) == (4,3)
    @test names(transpose(M2)) == (:c, :r)
    @test ranges(permutedims(M, (2,1))) == (2:5, 'a':'c')
    @test names(M3') == (:_, :r)

    @test_throws ArgumentError sum(M, dims=:nope)

    # sort
    @test sort(V)(20) == V(20)

    @test ranges(sort(M, dims=:c), :c) isa Base.OneTo
    @test ranges(sort(M, dims=:c), :r) == 'a':'c'

    @test sortslices(M, dims=:c) isa NamedDimsArray

end
@testset "map & collect" begin

    mapM =  map(exp, M)
    @test ranges(mapM) == ('a':'c', 2:5) # fails with nda(ra(...)), has lost ranges?
    @test names(mapM) == (:r, :c)

    @test ranges(map(+, M, M, M)) == ('a':'c', 2:5)
    @test ranges(map(+, M, parent(M))) == ('a':'c', 2:5)

    @test ranges(map(sqrt, V)) == (10:10:100,)

    V2 = wrapdims(rand(1:99, 10), v=2:11) # different range
    V3 = wrapdims(rand(1:99, 10), w=10:10:100) # different name
    @test_throws Exception map(+, V, V2)
    @test_skip map(+, V, V3) # should throw an error

    genM =  [exp(x) for x in M]
    @test ranges(genM) == ('a':'c', 2:5) # fails with nda(ra(...))
    @test_broken names(genM) == (:r, :c) # works with NamedDims#map

    @test ranges([exp(x) for x in V]) == (10:10:100,)

    gen3 = [x+y for x in M, y in V];
    @test ranges(gen3) == ('a':'c', 2:5, 10:10:100)
    @test_broken names(gen3) == (:r, :c, :v) # works with NamedDims#map

    gen1 = [x^i for (i,x) in enumerate(V)]
    @test ranges(gen1) == (10:10:100,)
    @test_broken names(gen1) == (:v,) # works with NamedDims#map

end
@testset "cat" begin

    # concatenation
    @test ranges(hcat(M,M)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5]) # fails with nda(ra(...))
    @test ranges(vcat(M,M)) == (['a', 'b', 'c', 'a', 'b', 'c'], 2:5)

    V = wrapdims(rand(1:99, 3), r=['a', 'b', 'c'])
    @test ranges(hcat(M,V)) == ('a':'c', [2, 3, 4, 5, 1])
    @test ranges(hcat(V,V),2) === Base.OneTo(2)

    @test ranges(vcat(V,V),1) == ['a', 'b', 'c', 'a', 'b', 'c']
    @test ranges(vcat(V', V')) == (1:2, ['a', 'b', 'c'])

    @test hcat(M, ones(3)) == hcat(M.data, ones(3))
    @test ranges(hcat(M, ones(3))) == ('a':1:'c', [2, 3, 4, 5, 1])

end
@testset "copy etc" begin

    # copy, similar, etc
    @test ranges(copy(M)) == ('a':'c', 2:5)
    @test zero(M)('a',2) == 0

    @test ranges(similar(M, Int)) == ranges(M)
    @test AxisRanges.hasranges(similar(M, Int, 3,3)) == false
    @test names(similar(M, 3,3)) == (:r, :c)
    @test AxisRanges.hasnames(similar(M, 2,2,2)) == false

end
