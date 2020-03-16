using Test, AxisKeys

@testset "basics" begin

    R = KeyedArray(rand(1:99, 3,4), (['a', 'b', 'c'], 10:10:40))
    @test axiskeys(R) == (['a', 'b', 'c'], 10:10:40)
    @test axiskeys(R,5) === Base.OneTo(1)

    @test R('c', 40) == R[3, 4]
    @test R(:, 30) == R[:, 3]

    @test R('b') == R[2,:]
    @test axiskeys(R(20)) == (['a', 'b', 'c'],)

    @test AxisKeys.setkey!(R, 123, 'a', 10) == 123
    @test R[1,1] == 123

    @test R('a', 10, :) isa SubArray{Int,0}
    R('a', 10, :) .= 321
    @test R[1,1] == 321

    @test R[:] == vec(R.data)
    @test_broken R[1:2, 1, 1] == R.data[1:2, 1, 1] # trailing 1s are broken
    @test axiskeys(R[:, [0.9,0.1,0.9,0.1] .> 0.5],2) == [10,30]
    @test_broken ndims(R[R.data .> 0.5]) == 1 # BitArray{2} is broken

    @test_throws Exception R(:nope) # ideally ArgumentError
    @test_throws Exception R('z')   # ideally BoundsError?
    @test_throws Exception R(99)
    @test_throws Exception R('c', 99)
    @test_throws BoundsError axiskeys(R,0)
    @test_throws Exception KeyedArray(rand(3,4), (['a', 'b'], 10:10:40)) # keys wrong length

    C = wrapdims(rand(10), 'a':'j')
    @test C('a':'c') == C[1:3]
    @test C(Base.Fix2(<=,'c')) == C[1:3]
    @test_skip axiskeys(C(Base.Fix2(<=,'c')),1) == 'a':'c' # ('a':'z')[1:3] isa StepRangeLen

    D = wrapdims(rand(2,10,3) .+ (1:10)'./10, ["cat", "dog"], 0:10:90, nothing)
    @test D("cat") == D[1,:,:]
    @test_throws Exception D(10) # ambiguous
    @test_throws Exception D("cat", 10) # too few
    @test_throws Exception D("cat", 10, -10) # out of bounds

    E = wrapdims(ComplexF32, [:a, :b], [:c, :d, :e])
    @test E(:a, :e) isa ComplexF32
    @test_throws Exception E(:a) # ambiguous

    F = wrapdims(rand(5), 'a':'z')
    @test axiskeys(F,1) == 'a':'e'
    @test_throws Exception wrapdims(rand(5), ['a','b','c'])
    @test_throws Exception KeyedArray(rand(5), ['a','b','c'])

end
@testset "selectors" begin

    V = wrapdims(rand(Int8, 11), 0:0.1:1)

    @test V(==(0.1)) == V[2:2]
    @test V(Near(0.12)) == V(0.1) == V[2]
    @test V(Interval(0.1, 0.3)) == V[2:4]

    @test V(Index[1]) == V[1]
    @test V(Index[2:3]) == V[2:3]
    @test V(Index[end]) == V[end]

    V2 = wrapdims(rand(Int8, 5), [1,2,3,2,1])
    @test V2(==(2)) == V2[[2,4]]
    @test V2(==(2.0)) == V2[[2,4]]
    @test V2(Near(2.3)) == V2[2]
    @test V2(Interval(0.5, 1.5)) == V2[[1,5]]

    R = KeyedArray(rand(1:99, 3,4), (['a', 'b', 'c'], 10:10:40))
    @test R(==('a')) == R[1:1, :]
    @test R(Near(23)) == R[:, 2]
    @test R(Near(23.5)) == R[:, 2] # promotes to Real & then matches
    @test R(Interval(17,23)) == R[:, 2:2]
    @test R(Base.Fix2(<=,23)) == R[:, 1:2]
    @test axiskeys(R(Base.Fix2(<=,23)), 2) isa AbstractRange

    @test_throws BoundsError V(Index[99])

end
@testset "names" begin

    # constructor
    @test dimnames(wrapdims(rand(3), :a)) == (:a,)
    @test dimnames(wrapdims(rand(3), b=1:3), 1) == :b
    @test axiskeys(wrapdims(rand(3), b=1:3)) == (1:3,)
    @test axiskeys(wrapdims(rand(3), b=1:3), :b) == 1:3

    # @test namedaxiskeys(wrapdims(rand(3), b=1:3)) === (b = 1:3,)
    # @test namedaxes(wrapdims(rand(3), b=1:3)) === (b = Base.OneTo(3),)

    # internal functions of NamedDims
    @test NamedDims.dimnames(rand(2,2)) === (:_, :_)
    @test NamedDims.dim((:a, :b, :c), :b) == 2
    @test NamedDims.order_named_inds(Val((:a, :b, :c)); a=1, c=2:3) === (1, Colon(), 2:3)
    @test 0 == @allocated NamedDims.order_named_inds(Val((:a, :b, :c)); a=1, c=2:3)

    # indexing etc, of commutative wrappers
    data = rand(1:99, 3,4)
    N1 = wrapdims(data, obs = ['a', 'b', 'c'], iter = 10:10:40)
    N2 = NamedDimsArray(KeyedArray(data, axiskeys(N1)), dimnames(N1))
    N3 = KeyedArray(NamedDimsArray(data, dimnames(N1)), axiskeys(N1))

    @testset "with $(typeof(N).name) outside" for N in [N2, N3]
        @test axiskeys(N) == (['a', 'b', 'c'], 10:10:40)
        @test axiskeys(N, :iter) == 10:10:40
        @test dimnames(N) == (:obs, :iter)
        @test axes(N, :obs) == 1:3
        @test size(N, :obs) == 3

        @test propertynames(N) == (:obs, :iter)
        @test N.obs == ['a', 'b', 'c']

        @test N(obs='a', iter=40) == N[obs=1, iter=4]
        @test N(obs='a') == N('a') == N[1,:] == N[obs=1]
        @test N(obs='a') == N('a') == view(N, 1,:) == view(N, obs=1)

        @test dimnames(N(obs='a')) == (:iter,)
        @test axiskeys(N(obs='b')) == (10:10:40,)

        @test_throws Exception N(obs=55)  # ideally ArgumentError
        @test_throws Exception N(obs='z') # ideally BoundsError
    end

end
@testset "broadcasting" begin
    using Base: OneTo
    @testset "keys" begin

        V = wrapdims(rand(Int8, 11), 0:0.1:1)
        @test axiskeys(V .+ 10) == axiskeys(V)
        @test axiskeys(V .+ V') == (axiskeys(V,1), axiskeys(V,1))
        @test axiskeys(V .+ rand(3)') === (axiskeys(V,1), OneTo(3))
        @test axiskeys(V .+ rand(11)) == (axiskeys(V,1),)

        M = wrapdims(rand(Int8, 3,11), [:a, :b, :c], 0:0.1:1)
        @test axiskeys(M .+ V') == axiskeys(M)

        W = wrapdims(rand(11), 0.1:0.1:1.1)
        @test axiskeys(V .+ W') == (axiskeys(V,1), axiskeys(W,1))
        @test_throws Exception axiskeys(V .+ W)

    end
    @testset "with names" begin

        vec_x = wrapdims(ones(2), :x)
        vec_y = wrapdims(ones(2), y='α':'β')
        mat_r = wrapdims(ones(2,2), 11:12, 'α':'β')
        mat_y = wrapdims(ones(2,2), :_, :y)

        @test axiskeys(vec_x .+ mat_r .+ mat_y) == axiskeys(mat_r)
        @test dimnames(vec_x .+ mat_r .+ mat_y) == (:x, :y)

        @test axiskeys(sqrt.(vec_x .+ vec_y') ./ mat_r) == axiskeys(mat_r)
        @test dimnames(sqrt.(vec_x .+ vec_y') ./ mat_r) == (:x, :y)

        yy = vec_y .+ mat_y
        @test axiskeys(yy' .+ mat_r) == (11:12, 'α':'β')

        @test_throws Exception vec_x .+ vec_y

    end
    @testset "in-place" begin

        v1 = wrapdims(ones(2), ["a", "b"])
        v2 = wrapdims(ones(2), :μ)
        v3 = wrapdims(ones(2), [11, 22])
        z = zeros(2,2)

        @test dimnames(v1 .= v1 .+ v2) == (:μ,)
        @test v1[1] == 2

        @test dimnames(v2 .= v3 .+ 5) == (:μ,)
        @test v2[1] == 6

        @test axiskeys(z .= v1 .+ v2') == (["a", "b"], Base.OneTo(2))

        @test_throws Exception v3 .= v1 .+ v2
        @test_throws Exception zeros(2) .= v1 .+ v3

    end
    @testset "unify rules" begin

        using AxisKeys: who_wins
        @test who_wins(1:2, [1,2]) === 1:2
        @test who_wins(1:2, 1.0:2.0) === 1:2
        @test who_wins(OneTo(2), [3,4]) == [3,4]
        @test who_wins(1:2, [3,4]) === nothing

        using AxisKeys: unify_keys, unify_longest
        @test unify_keys((OneTo(2), 1:2), (3:4, [1,2])) === (3:4, 1:2)
        @test unify_longest((OneTo(2), 1:2), (3:4, [1,2], [0,1])) == (3:4, 1:2, [0,1])
        @test_throws Exception unify_keys((1:2,), ([3,4],))

    end
end
@testset "mutation" begin

    V = wrapdims([3,5,7,11], μ=10:10:40)
    @test axiskeys(push!(V, 13)) == (10:10:50,)

    @test pop!(V) == 13
    @test axiskeys(V) == (10:10:40,)

    V2 = KeyedArray(rand(3), Base.OneTo(3))
    @test axiskeys(push!(V2, 0)) === (Base.OneTo(4),)
    @test axiskeys(append!(V2, [7,7])) === (Base.OneTo(6),)

    AxisKeys.OUTER[]==:KeyedArray && # fails with nda(ka(...))
        @test axiskeys(append!(V2, V),1) == [1, 2, 3, 4, 5, 6, 10, 20, 30, 40]

    W = wrapdims([1,2,3], ["a", "b", "c"])
    push!(W, d=4)
    push!(W, "e" => 5)
    @test axiskeys(W,1) == ["a", "b", "c", "d", "e"]

end
