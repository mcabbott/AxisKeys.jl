
@testset "basics" begin

    R = RangeArray(rand(1:99, 3,4), (['a', 'b', 'c'], 10:10:40))
    @test ranges(R) == (['a', 'b', 'c'], 10:10:40)
    @test ranges(R,5) === Base.OneTo(1)

    @test R('c', 40) == R[3, 4]
    @test R(:, 30) == R[:, 3]

    @test R('b') == R[2,:]
    @test ranges(R(20)) == (['a', 'b', 'c'],)

    @test AxisRanges.setkey!(R, 123, 'a', 10) == 123
    @test R[1,1] == 123

    @test R[:] == vec(R.data)
    @test_broken R[1:2, 1, 1] == R.data[1:2, 1, 1]

    @test_throws Exception R(:nope) # ideally ArgumentError
    @test_throws Exception R('z')   # ideally BoundsError
    @test_throws Exception R(99)
    @test_throws Exception R('c', 99)
    @test_throws BoundsError ranges(R,0)

    C = wrapdims(rand(10), 'a':'j')
    @test C('a':'c') == C[1:3]
    @test C(Base.Fix2(<=,'c')) == C[1:3]
    @test_skip ranges(C(Base.Fix2(<=,'c')),1) == 'a':'c' # ('a':'z')[1:3] isa StepRangeLen

    D = wrapdims(rand(2,10,3) .+ (1:10)'./10, ["cat", "dog"], 0:10:90, nothing)
    @test D("cat") == D[1,:,:]
    @test_throws Exception D(10) # ambiguous
    @test_throws Exception D("cat", 10) # too few
    @test_throws Exception D("cat", 10, -10) # out of bounds

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
    @test R(Base.Fix2(<=,23)) == R[:, 1:2]
    @test_skip ranges(R(Base.Fix2(<=,23)), 2) isa AbstractRange

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

    @testset "with $(typeof(N).name) outside" for N in [N2, N3]
        @test ranges(N) == (['a', 'b', 'c'], 10:10:40)
        @test ranges(N, :iter) == 10:10:40
        @test names(N) == (:obs, :iter)
        @test axes(N, :obs) == 1:3

        @test_skip propertynames(N) == (:obs, :iter) # commented out, for speed
        @test_skip N.obs == ['a', 'b', 'c']

        @test N(obs='a', iter=40) == N[obs=1, iter=4]
        @test N(obs='a') == N('a') == N[1,:]

        @test names(N(obs='a')) == (:iter,)
        @test ranges(N(obs='b')) == (10:10:40,)

        @test_throws Exception N(obs=55)  # ideally ArgumentError
        @test_throws Exception N(obs='z') # ideally BoundsError
    end

end
@testset "broadcasting" begin

    V = wrapdims(rand(Int8, 11), 0:0.1:1)
    @test_broken ranges(V .+ 10) == ranges(V)
    @test_broken ranges(V .+ V') == (ranges(V,1), ranges(V,1))

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

    @test ranges(append!(V2, V),1) == [1, 2, 3, 4, 5, 6, 10, 20, 30, 40] # fails with nda(ra(...))

end
