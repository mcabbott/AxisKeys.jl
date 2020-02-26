using Test, AxisRanges, Statistics

M = RangeArray(rand(Int8, 3,4), r='a':'c', c=2:5)
MN = NamedDimsArray(M.data.data, r='a':'c', c=2:5)
V = wrapdims(rand(1:99, 10), v=10:10:100)

@testset "dims" begin

    # reductions
    M1 = sum(M, dims=1)
    @test ranges(M1, 1) === Base.OneTo(1)

    M2 = prod(M, dims=:c)
    @test ranges(M2) == ('a':'c', Base.OneTo(1))

    @test_throws ArgumentError sum(M, dims=:nope)

    M4 = mean(M, dims=:c)
    @test ranges(M4) === ('a':'c', Base.OneTo(1))

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
    @test ranges(transpose(transpose(V))) == ranges(V)
    @test ranges(permutedims(transpose(V))) == (ranges(V,1), Base.OneTo(1))

    V2 = wrapdims(rand(3), along=[:a, :b, :c])
    ranges(permutedims(V2), 2)[1] = :nope
    @test ranges(V2,1) == [:a, :b, :c]
    ranges(V2', 2)[1] = :zed
    @test ranges(V2,1) == [:zed, :b, :c]

    # sort
    @test sort(V)(20) == V(20)

    @test ranges(sort(M, dims=:c), :c) isa Base.OneTo
    @test ranges(sort(M, dims=:c), :r) == 'a':'c'

    @test sortslices(M, dims=:c) isa NamedDimsArray

    # reshape
    @test reshape(M, 4,3) isa Array
    @test reshape(M, 2,:) isa Array
    @test reshape(M, (4,3)) isa Array
    @test reshape(M, (2,:)) isa Array

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
    @test names(genM) == (:r, :c)

    @test ranges([exp(x) for x in V]) == (10:10:100,)

    gen3 = [x+y for x in M, y in V];
    @test ranges(gen3) == ('a':'c', 2:5, 10:10:100)
    @test names(gen3) == (:r, :c, :v)

    gen1 = [x^i for (i,x) in enumerate(V)]
    @test ranges(gen1) == (10:10:100,)
    @test names(gen1) == (:v,)

    @test ranges(filter(isodd, V2),1) isa Vector{Int}
    @test names(filter(isodd, V2)) == (:v,)

    @test filter(isodd, M) isa Array

end
@testset "cat" begin

    # concatenation
    @test ranges(hcat(M,M)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5])
    @test ranges(vcat(M,M)) == (['a', 'b', 'c', 'a', 'b', 'c'], 2:5)
    @test ranges(hcat(MN,MN)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5])
    @test ranges(hcat(M,MN)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5])

    V = wrapdims(rand(1:99, 3), r=['a', 'b', 'c'])
    @test ranges(hcat(M,V)) == ('a':'c', [2, 3, 4, 5, 1]) # fails with nda(ra(...))
    @test ranges(hcat(V,V),2) === Base.OneTo(2)

    @test ranges(vcat(V,V),1) == ['a', 'b', 'c', 'a', 'b', 'c']
    @test ranges(vcat(V', V')) == (1:2, ['a', 'b', 'c'])

    @test hcat(M, ones(3)) == hcat(M.data, ones(3))
    @test ranges(hcat(M, ones(3))) == ('a':1:'c', [2, 3, 4, 5, 1])

    @test ranges(cat(M,M, dims=3)) == ('a':1:'c', 2:5, Base.OneTo(2))
    @test ranges(cat(M.data,M,M, dims=3)) == ('a':1:'c', 2:5, Base.OneTo(3))
    @test ranges(cat(M,M, dims=(1,2))) == (['a','b','c', 'a','b','c'], [2,3,4,5, 2,3,4,5])

    @test ranges(cat(MN,MN, dims=3)) == ('a':1:'c', 2:5, Base.OneTo(2))
    @test ranges(cat(M,MN, dims=3)) == ('a':1:'c', 2:5, Base.OneTo(2))

    @test_broken ranges(cat(M,M, dims=:r)) # doesn't work in NamedDims either

end
@testset "matmul" begin

    # two matrices
    @test ranges(M * M') === ('a':'c', 'a':'c')
    @test ranges(M * rand(4,5)) === ('a':'c', Base.OneTo(5))
    @test ranges(rand(2,3) * M) === (Base.OneTo(2), 2:5)
    @test ranges(MN * MN') === ('a':'c', 'a':'c')
    @test ranges(M * MN') === ('a':'c', 'a':'c')

    # two vectors
    @test (V' * V) isa Int
    @test (V' * rand(Int, 10)) isa Int
    @test (rand(Int, 10)' * V) isa Int
    @test ranges(V * V') === (10:10:100, 10:10:100)
    @test names(V * V') === (:v, :v)
    @test ranges(V * rand(1,10)) === (10:10:100, Base.OneTo(10))
    @test names(V * rand(1,10)) === (:v, :_)

    # matrix * vector
    @test ranges(M * M('a')) === ('a':'c',)
    @test names(M * M('a')) === (:r,)
    @test ranges(M(5)' * M) === (Base.OneTo(1), 2:5)
    @test names(M(5)' * M) === (:_, :c)

end
@testset "div" begin # doesn't work for names yet

    A = wrapdims(rand(Int8,3,4), 'a':'c', 10:10:40)
    C = wrapdims(rand(Int8,3), ['a', 'b', 'c'])
    D = wrapdims(rand(Int8,4), [10, 20, 30, 40])

    @test ranges(A \ A) == (10:10:40, 10:10:40)
    @test ranges(A \ C) == (10:10:40,)
    @test ranges(A' \ D) == ('a':'c',)

end
@testset "copy etc" begin

    # copy, similar, etc
    @test ranges(copy(M)) == ('a':'c', 2:5)
    @test ranges(copy(MN)) == ('a':'c', 2:5)
    @test zero(M)('a',2) == 0
    @test zero(MN)('a',2) == 0

    @test ranges(similar(M, Int)) == ranges(M)
    @test ranges(similar(MN, Int)) == ranges(M)
    @test AxisRanges.hasranges(similar(M, Int, 3,3)) == false
    @test AxisRanges.hasranges(similar(MN, Int, 3,3)) == false
    @test names(similar(M, 3,3)) == (:r, :c)
    @test names(similar(MN, 3,3)) == (:r, :c)
    @test AxisRanges.hasnames(similar(M, 2,2,2)) == false
    @test AxisRanges.hasnames(similar(MN, 2,2,2)) == false

end
@testset "equality" begin

    data = parent(parent(M))
    M2 = wrapdims(data, r='a':'c', c=[2,3,4,5]) # same values
    M3 = wrapdims(data, 'a':'c', 2:5) # no names but same ranges
    M4 = wrapdims(data, r='a':'c', c=nothing) # missing range
    @test M == M2 == M3 == M4
    @test isequal(M, M2) && isequal(M, M3) && isequal(M, M4)
    @test M ≈ M2 ≈ M3 ≈ M4

    M5 = wrapdims(data, r='a':'c', c=4:7) # wrong range
    M6 = wrapdims(data, r='a':'c', nope=2:5) # wrong name
    M7 = wrapdims(2 .* data, r='a':'c', c=2:5) # wrong data
    @test M != M5 # fails with nda(ra(...))
    @test M != M6
    @test M != M7
    @test !isapprox(M, M5) && !isapprox(M, M7) # errors with nda(ra(...))

    @test M == MN

end
