
M = wrapdims(rand(Int8, 3,4), r='a':'c', c=2:5)

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

end
@testset "map etc" begin

    # map & collect
    mapM =  map(exp, M)
    @test ranges(mapM) == ('a':'c', 2:5) # fails with nda(ra(...)), has lost ranges?
    @test names(mapM) == (:r, :c)

    genM =  [exp(x) for x in M]
    @test ranges(genM) == ('a':'c', 2:5) # fails with nda(ra(...))
    @test_broken names(genM) == (:r, :c)

end
@testset "cat" begin

    # concatenation
    @test ranges(hcat(M,M)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5]) # fails with nda(ra(...))
    @test ranges(vcat(M,M)) == (['a', 'b', 'c', 'a', 'b', 'c'], 2:5)
    V = wrapdims(rand(1:99, 3), r=['a', 'b', 'c'])
    @test ranges(hcat(M,V)) == ('a':'c', [2, 3, 4, 5, 1])
    @test ranges(hcat(V,V),2) === Base.OneTo(2)

    @test hcat(M, ones(3)) == hcat(M.data, ones(3))
    @test_broken ranges(hcat(M, ones(3))) == ('a':1:'c', 2:6)

end
@testset "copy etc" begin

    # copy, similar, etc
    @test ranges(copy(M)) == ('a':'c', 2:5)
    @test zero(M)('a',2) == 0
    @test eltype(similar(M, Float64)) == Float64

end
