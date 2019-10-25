using Test, AxisRanges, OffsetArrays

@testset "basics" begin
    R = RangeArray(rand(1:99, 3,4), (['a', 'b', 'c'], 10:10:40))
    @test ranges(R) == (['a', 'b', 'c'], 10:10:40)
    @test ranges(R,5) === Base.OneTo(1)

    @test R('c', 40) == R[3, 4]

    @test R('b') == R[2,:]
    @test ranges(R(20)) == (['a', 'b', 'c'],)

    @test_throws Exception R(:nope) # ideally ArgumentError
    @test_throws Exception R('z')   # ideally BoundsError
    @test_throws Exception R(99)
    @test_throws Exception R('c', 99)
    @test_throws BoundsError ranges(R,0)
end

@testset "selectors" begin
    V = wrapdims(rand(Int8, 11), 0:0.1:1)

    @test V(All(0.1)) == V[2:2]
    @test V(Near(0.12)) == V(0.1) == V[2]
    @test V(Between(0.1, 0.3)) == V[2:4]

    @test V(Index[1]) == V[1]
    @test V(Index[end]) == V[end]

    V2 = wrapdims(rand(Int8, 5), [1,2,3,2,1])
    @test V2(All(2)) == V2[[2,4]]
    @test V2(Near(2.3)) == V2[2]
    @test V2(Between(0.5, 1.5)) == V2[[1,5]]

    @test_throws BoundsError V(Index[99])
end

@testset "names" begin
    data = rand(1:99, 3,4)
    N1 = wrapdims(data, obs = ['a', 'b', 'c'], iter = 10:10:40)
    N2 = NamedDimsArray(RangeArray(data, ranges(N1)), names(N1))
    N3 = RangeArray(NamedDimsArray(data, names(N1)), ranges(N1))

    for N in [N1, N2, N3]
        @test ranges(N) == (['a', 'b', 'c'], 10:10:40)
        @test names(N) == (:obs, :iter)

        @test N(obs='a', iter=40) == N[obs=1, iter=4]
        @test N(obs='a') == N('a') == N[1,:]

        @test names(N(obs='a')) == (:iter,)
        @test ranges(N(obs='b')) == (10:10:40,)

        @test_throws Exception N(obs=55)  # ideally ArgumentError
        @test_throws Exception N(obs='z') # ideally BoundsError
    end
end

@testset "functions" begin
    M = wrapdims(rand(Int8, 3,4), r='a':'c', c=2:5)

    # Reductions
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

    # map & collect
    mapM =  map(exp, M)
    @test ranges(mapM) == ('a':'c', 2:5)
    @test names(mapM) == (:r, :c)

    genM =  [exp(x) for x in M]
    @test ranges(genM) == ('a':'c', 2:5)
    @test_broken names(genM) == (:r, :c)

    # copy, similar, etc
    @test ranges(copy(M)) == ('a':'c', 2:5)
    @test zero(M)('a',2) == 0
    @test eltype(similar(M, Float64)) == Float64
end

@testset "mutation" begin
    V = wrapdims([3,5,7,11], μ=10:10:40)
    @test ranges(push!(V, 13)) == (10:10:50,)

    @test pop!(V) == 13
    @test ranges(V) == (10:10:40,)

    V2 = RangeArray(rand(3))
    @test ranges(push!(V2, 0)) === (Base.OneTo(4),)
    @test ranges(append!(V2, [7,7])) === (Base.OneTo(6),)

    # @test_broken append!(V2, V)
end

@testset "offset" begin
    o = OffsetArray(rand(1:99, 5), -2:2)
    w = wrapdims(o, i='a':'e')
    @test w[i=-2] == w('a')
end

@testset "non-piracy" begin
    @test AxisRanges.filter(iseven, (1,2,3,4)) === (2,4)

    @test AxisRanges.map(sqrt, Ref(4))[] == 2.0
    @test AxisRanges.map(sqrt, Ref(4)) isa Ref

    @test AxisRanges.map(+, Ref(2), (3,))[] == 5
    @test AxisRanges.map(+, Ref(2), (3,)) isa Ref

    for r in (Base.OneTo(5), 2:5)
        for x in -2:7

            @test AxisRanges.findfirst(==(x), r) == findfirst(==(x), collect(r))
            @test AxisRanges.findfirst(isequal(x), r) == findfirst(isequal(x), collect(r))

            for op in (isequal, Base.:(==), Base.:<, Base.:<=, Base.:>, Base.:>=)

                @test AxisRanges.findall(op(x), r) == findall(op(x), collect(r))
                @test AxisRanges.findall(op(x), r) isa AbstractRange
                # T = typeof(AxisRanges.findall(op(x), r))
                # T <: AbstractRange || @info "$op($x) $r  -> $T"
            end

        end
    end
end
