using Test, AxisRanges, NamedDims, OffsetArrays, Tables

@testset "basics" begin
    R = RangeArray(rand(1:99, 3,4), (['a', 'b', 'c'], 10:10:40))
    @test ranges(R) == (['a', 'b', 'c'], 10:10:40)
    @test ranges(R,5) === Base.OneTo(1)

    @test R('c', 40) == R[3, 4]

    @test R('b') == R[2,:]
    @test ranges(R(20)) == (['a', 'b', 'c'],)

    @test AxisRanges.setkey!(R, 123, 'a', 10) == 123
    @test R[1,1] == 123

    @test_throws Exception R(:nope) # ideally ArgumentError
    @test_throws Exception R('z')   # ideally BoundsError
    @test_throws Exception R(99)
    @test_throws Exception R('c', 99)
    @test_throws BoundsError ranges(R,0)
end

@testset "selectors" begin
    V = wrapdims(rand(Int8, 11), 0:0.1:1)

    @test V(==(0.1)) == V[2:2]
    @test V(Nearest(0.12)) == V(0.1) == V[2]
    @test V(Between(0.1, 0.3)) == V[2:4]

    @test V(Index[1]) == V[1]
    @test V(Index[2:3]) == V[2:3]
    @test V(Index[end]) == V[end]

    V2 = wrapdims(rand(Int8, 5), [1,2,3,2,1])
    @test V2(==(2)) == V2[[2,4]]
    @test V2(==(2.0)) == V2[[2,4]]
    @test V2(Nearest(2.3)) == V2[2]
    @test V2(Between(0.5, 1.5)) == V2[[1,5]]

    R = RangeArray(rand(1:99, 3,4), (['a', 'b', 'c'], 10:10:40))
    @test R(==('a')) == R[1:1, :]
    @test R(Nearest(23)) == R[:, 2]
    @test R(Between(17,23)) == R[:, 2:2]
    @test R(<=(23)) == R[:, 1:2]
    @test_broken ranges(R(<=(23)), 2) isa AbstractRange

    @test_throws BoundsError V(Index[99])
    @test_throws Exception R(Nearest(23.5)) # ideally ArgumentError
end

@testset "names" begin
    # constructor
    @test names(wrapdims(rand(3), :a)) == (:a,)
    @test names(wrapdims(rand(3), b=1:3), 1) == :b
    @test ranges(wrapdims(rand(3), b=1:3)) == (1:3,)
    @test ranges(wrapdims(rand(3), b=1:3), :b) == 1:3

    @test namedranges(wrapdims(rand(3), b=1:3)) === (b = 1:3,)
    @test namedaxes(wrapdims(rand(3), b=1:3)) === (b = Base.OneTo(3),)

    # internal functions of NamedDims
    @test NamedDims.names(rand(2,2)) === (:_, :_)
    @test NamedDims.dim((:a, :b, :c), :b) == 2
    @test NamedDims.order_named_inds((:a, :b, :c); a=1, c=2:3) === (1, Colon(), 2:3)
    @test_skip 0 == @allocated NamedDims.order_named_inds((:a, :b, :c); a=1, c=2:3)

    # indexing etc, of commutative wrappers
    data = rand(1:99, 3,4)
    N1 = wrapdims(data, obs = ['a', 'b', 'c'], iter = 10:10:40)
    N2 = NamedDimsArray(RangeArray(data, ranges(N1)), names(N1))
    N3 = RangeArray(NamedDimsArray(data, names(N1)), ranges(N1))

    for N in [N1, N2, N3]
        @test ranges(N) == (['a', 'b', 'c'], 10:10:40)
        @test names(N) == (:obs, :iter)
        @test_skip propertynames(N) == (:obs, :iter)
        @test_skip N.obs == ['a', 'b', 'c']

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

    # map & collect
    mapM =  map(exp, M)
    @test ranges(mapM) == ('a':'c', 2:5)
    @test names(mapM) == (:r, :c)

    genM =  [exp(x) for x in M]
    @test ranges(genM) == ('a':'c', 2:5)
    @test_broken names(genM) == (:r, :c)

    # concatenation
    @test ranges(hcat(M,M)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5])
    @test ranges(vcat(M,M)) == (['a', 'b', 'c', 'a', 'b', 'c'], 2:5)
    V = wrapdims(rand(1:99, 3), r=['a', 'b', 'c'])
    @test ranges(hcat(M,V)) == ('a':'c', [2, 3, 4, 5, 1])
    @test ranges(hcat(V,V),2) === Base.OneTo(2)

    @test hcat(M, ones(3)) == hcat(M.data, ones(3))
    @test_broken ranges(hcat(M, ones(3))) == ('a':1:'c', 2:6)

    # copy, similar, etc
    @test ranges(copy(M)) == ('a':'c', 2:5)
    @test zero(M)('a',2) == 0
    @test eltype(similar(M, Float64)) == Float64
end

@testset "broadcasting" begin

    using AxisRanges: who_wins
    @test who_wins(1:2, [1,2]) === 1:2
    @test who_wins(1:2, 1.0:2.0) === 1:2
    @test who_wins(Base.OneTo(2), [3,4]) == [3,4]

end

@testset "mutation" begin
    V = wrapdims([3,5,7,11], μ=10:10:40)
    @test ranges(push!(V, 13)) == (10:10:50,)

    @test pop!(V) == 13
    @test ranges(V) == (10:10:40,)

    V2 = RangeArray(rand(3))
    @test ranges(push!(V2, 0)) === (Base.OneTo(4),)
    @test ranges(append!(V2, [7,7])) === (Base.OneTo(6),)

    @test ranges(append!(V2, V),1) == [1, 2, 3, 4, 5, 6, 10, 20, 30, 40]
end

@testset "offset" begin
    o = OffsetArray(rand(1:99, 5), -2:2)
    w = wrapdims(o, i='a':'e')
    @test w[i=-2] == w('a')
end

@testset "tables" begin
    R = wrapdims(rand(2,3), 11:12, 21:23)
    N = wrapdims(rand(2,3), a=[11, 12], b=[21, 22, 23.0])

    @test keys(first(Tables.rows(R))) == (:dim_1, :dim_2, :value)
    @test keys(first(Tables.rows(N))) == (:a, :b, :value)

    @test Tables.columns(N).a == [11, 12, 11, 12, 11, 12]
end

@testset "non-piracy" begin
    @test AxisRanges.filter(iseven, (1,2,3,4)) === (2,4)
    if VERSION >= v"1.2" # fails on 1.0
        @test 0 == @allocated AxisRanges.filter(iseven, (1,2,3,4))
    end

    @test AxisRanges.map(sqrt, Ref(4))[] == 2.0
    @test AxisRanges.map(sqrt, Ref(4)) isa Ref

    @test AxisRanges.map(+, Ref(2), (3,))[] == 5
    @test AxisRanges.map(+, Ref(2), (3,)) isa Ref
    @test AxisRanges.map(+, (2,), Ref(3)) isa Ref
    @test 0 == @allocated AxisRanges.map(+, (2,), Ref(3))

    @test AxisRanges._Tuple((1,2)) === (1,2)
    @test AxisRanges._Tuple(Ref(3)) === (3,)
    @test 0 == @allocated AxisRanges._Tuple(Ref(3))

    for r in (Base.OneTo(5), 2:5)
        for x in -2:7

            @test AxisRanges.findfirst(==(x), r) == findfirst(==(x), collect(r))
            @test AxisRanges.findfirst(isequal(x), r) == findfirst(isequal(x), collect(r))

            if VERSION >= v"1.2" # <(3) doesn't exist on 1.1, but Base.Fix2 is fine
            for op in (isequal, Base.:(==), Base.:<, Base.:<=, Base.:>, Base.:>=)

                @test AxisRanges.findall(op(x), r) == findall(op(x), collect(r))
                @test AxisRanges.findall(op(x), r) isa AbstractRange
                # T = typeof(AxisRanges.findall(op(x), r))
                # T <: AbstractRange || @info "$op($x) $r  -> $T"
            end
            end

        end
    end
end
