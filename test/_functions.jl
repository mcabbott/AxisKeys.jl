using Test, AxisKeys, Statistics
using NamedDims: unname

M = wrapdims(rand(Int8, 3,4), r='a':'c', c=2:5)
MN = NamedDimsArray(M.data.data, r='a':'c', c=2:5)
V = wrapdims(rand(1:99, 10), v=10:10:100)
VN = NamedDimsArray(V.data.data, v=10:10:100)
A3 = wrapdims(rand(Int8, 3,4,2), r='a':'c', c=2:5, p=[10.0, 20.0])

@testset "dims" begin

    # reductions
    M1 = sum(M, dims=1)
    @test axiskeys(M1, 1) === Base.OneTo(1)

    M2 = prod(M, dims=:c)
    @test axiskeys(M2) == ('a':'c', Base.OneTo(1))

    @test_throws ArgumentError sum(M, dims=:nope)

    M4 = mean(M, dims=:c)
    @test axiskeys(M4) === ('a':'c', Base.OneTo(1))

    # dropdims
    @test axiskeys(dropdims(M1, dims=1)) == (2:5,)
    @test axiskeys(dropdims(M2, dims=:c)) == ('a':'c',)

    M3 = dropdims(M2, dims=:c)
    @test dimnames(M3) == (:r,)

    # permutedims
    @test size(permutedims(M)) == (4,3)
    @test dimnames(transpose(M2)) == (:c, :r)
    @test axiskeys(permutedims(M, (2,1))) == (2:5, 'a':'c')
    @test dimnames(M3') == (:_, :r)
    @test axiskeys(transpose(transpose(V))) == axiskeys(V) # fixed by NamedDims.jl/pull/105
    @test axiskeys(permutedims(transpose(V))) == (axiskeys(V,1), Base.OneTo(1))

    V2 = wrapdims(rand(3), along=[:a, :b, :c])
    axiskeys(permutedims(V2), 2)[1] = :nope
    @test axiskeys(V2,1) == [:a, :b, :c]
    axiskeys(V2', 2)[1] = :zed
    @test axiskeys(V2,1) == [:zed, :b, :c]

    # eachslice
    if VERSION >= v"1.1"
        @test axiskeys(first(eachslice(M, dims=:r))) === (2:5,)
    end

    @test axiskeys(selectdim(M, :r, [true, false, true])) == (['a', 'c'], 2:5)

    # mapslices
    @test axiskeys(mapslices(identity, M, dims=1)) === (Base.OneTo(3), 2:5)
    @test axiskeys(mapslices(sum, M, dims=1)) === (Base.OneTo(1), 2:5)
    @test axiskeys(mapslices(v -> rand(10), M, dims=2)) === ('a':'c', Base.OneTo(10))

    # reshape
    @test reshape(M, 4,3) isa Array
    @test reshape(M, 2,:) isa Array
    if AxisKeys.nameouter() == false  # reshape(keyless(M), (2,:)) # is an error
        @test reshape(M, (4,3)) isa Array
        @test reshape(M, (2,:)) isa Array
    end

end
@testset "mapreduce & keywords, issue 43" begin
    # https://github.com/mcabbott/AxisKeys.jl/issues/43

    z = KeyedArray(zeros(3); foo=[:a, :b, :c])
    @test mapreduce(identity, +, z; init=10) == 10

    m = KeyedArray([1, 2, 3]; foo=[:a, :b, :c])
    @test std(m; corrected=false) == std([1, 2, 3]; corrected=false)

end
@testset "sort & reverse" begin

    @test sort(V)(20) == V(20)

    @test axiskeys(sort(M, dims=:c), :c) isa Base.OneTo
    @test axiskeys(sort(M, dims=:c), :r) == 'a':'c'

    # sortslices
    @test sortslices(M, dims=:c) == sortslices(AxisKeys.keyless(M), dims=:c)
    @test axiskeys(sortslices(M, dims=:r), :r) isa Vector # not a steprange, it got sorted

    T = wrapdims(rand(Int8, 5,7,3), a=1:5, b=0:6.0, c='a':'c')
    T′ = sortslices(T, dims=:b)
    @test issorted(T′[a=1, c=1])
    @test T′ == sortslices(AxisKeys.keyless(T), dims=:b, by=vec)

    A = wrapdims([1,0], vec=[:a, :b]) # https://github.com/JuliaArrays/AxisArrays.jl/issues/172
    sort!(A)
    @test A(:a) == 1
    @test axiskeys(A, 1) == [:b, :a]
    @test_throws Exception sort!(KeyedArray([1,0], 'a':'b'))

    # sortkeys
    B = wrapdims(rand(Int8,3,7), 🚣=rand(Int8,3), 🏛=rand(Int8,7))
    p = sortperm(B.🏛; rev=true)
    B′ = sortkeys(B, dims=:🏛, rev=true)
    @test B′ == B[:,p]
    @test issorted(reverse(B′.🏛))

    # reverse
    @test parent(parent(reverse(V))) == reverse(parent(parent(V)))
    @test parent(parent(reverse(B))) == reverse(parent(parent(B)))
    if AxisKeys.nameouter()
        @test_broken axiskeys(reverse(V),1) == 100:-10:10
        @test_broken parent(parent(reverse(B, dims=:🏛))) == reverse(parent(parent(B)), dims=2)
    else
        # Handled by Base's fallback, doesn't touch key vector:
        @test axiskeys(reverse(V),1) == 100:-10:10
        # This throws: reverse(NamedDimsArray(rand(3), a=[1,10,100]), dims=:a)
        @test parent(parent(reverse(B, dims=:🏛))) == reverse(parent(parent(B)), dims=2)
        @test axiskeys(reverse(B, dims=:🏛)) == (axiskeys(B,1), reverse(axiskeys(B,2)))
    end
end
@testset "map & collect" begin

    mapM =  map(exp, M)
    @test axiskeys(mapM) == ('a':'c', 2:5)
    @test dimnames(mapM) == (:r, :c)

    @test axiskeys(map(+, M, M, M)) == ('a':'c', 2:5)
    @test axiskeys(map(+, M, parent(M))) == ('a':'c', 2:5)

    @test axiskeys(map(sqrt, V)) == (10:10:100,)

    V2 = wrapdims(rand(1:99, 10), v=2:11) # different keys
    V3 = wrapdims(rand(1:99, 10), w=10:10:100) # different name
    @test_throws Exception map(+, V, V2)
    @test_throws Exception map(+, V, V3) # should throw an error ???

    genM =  [exp(x) for x in M]
    @test axiskeys(genM) == ('a':'c', 2:5)
    @test dimnames(genM) == (:r, :c)

    @test axiskeys([exp(x) for x in V]) == (10:10:100,)

    gen3 = [x+y for x in M, y in V];
    @test axiskeys(gen3) == ('a':'c', 2:5, 10:10:100)
    @test dimnames(gen3) == (:r, :c, :v)

    gen1 = [x^i for (i,x) in enumerate(V)]
    @test axiskeys(gen1) == (10:10:100,)
    @test dimnames(gen1) == (:v,)

    @test axiskeys(filter(isodd, V2),1) isa Vector{Int}
    @test dimnames(filter(isodd, V2)) == (:v,)

    V4 = wrapdims(rand(1:99, 10), collect(2:11))
    V4c = copy(V4)
    @test filter!(isodd, V4c) === V4c == filter(isodd, V4)

    @test filter(isodd, M) isa Array

end
@testset "cat" begin

    # concatenation
    @test axiskeys(hcat(M,M)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5])
    @test axiskeys(vcat(M,M)) == (['a', 'b', 'c', 'a', 'b', 'c'], 2:5)
    @test axiskeys(hcat(MN,MN)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5])
    @test axiskeys(hcat(M,MN)) == ('a':'c', [2, 3, 4, 5, 2, 3, 4, 5])

    V = wrapdims(rand(1:99, 3), r=['a', 'b', 'c'])
    VN = NamedDimsArray(V.data.data, r=['a', 'b', 'c'])
    @test axiskeys(hcat(M,V)) == ('a':'c', [2, 3, 4, 5, 1])
    @test axiskeys(hcat(M,VN)) == ('a':'c', [2, 3, 4, 5, 1])
    @test axiskeys(hcat(MN,V)) == ('a':'c', [2, 3, 4, 5, 1])
    @test axiskeys(hcat(V,V),2) === Base.OneTo(2)
    @test axiskeys(hcat(V,VN),2) === Base.OneTo(2)

    @test axiskeys(vcat(V,V),1) == ['a', 'b', 'c', 'a', 'b', 'c']
    @test axiskeys(vcat(V,VN),1) == ['a', 'b', 'c', 'a', 'b', 'c']
    @test axiskeys(vcat(V', V')) == (1:2, ['a', 'b', 'c'])
    @test axiskeys(vcat(V', VN')) == (1:2, ['a', 'b', 'c'])

    @test hcat(M, ones(3)) == hcat(M.data, ones(3))
    @test axiskeys(hcat(M, ones(3))) == ('a':1:'c', [2, 3, 4, 5, 1])

    @test axiskeys(cat(M,M, dims=3)) == ('a':1:'c', 2:5, Base.OneTo(2))
    @test axiskeys(cat(M.data,M,M, dims=3)) == ('a':1:'c', 2:5, Base.OneTo(3))
    @test axiskeys(cat(M,M, dims=(1,2))) == (['a','b','c', 'a','b','c'], [2,3,4,5, 2,3,4,5])

    @test axiskeys(cat(MN,MN, dims=3)) == ('a':1:'c', 2:5, Base.OneTo(2))
    @test axiskeys(cat(M,MN, dims=3)) == ('a':1:'c', 2:5, Base.OneTo(2))

    @test axiskeys(cat(M,M, dims=:z)) == ('a':1:'c', 2:5, Base.OneTo(2))
    @test dimnames(cat(M,M, dims=:z)) == (:r, :c, :z)

    @test axiskeys(cat(A3, A3, dims=:p)) == ('a':1:'c', 2:5, [10.0, 20.0, 10.0, 20.0])
    @test axiskeys(hcat(A3, A3)) == ('a':1:'c', vcat(2:5,2:5), [10.0, 20.0])

    # reduce(*cat, a_of_as)
    vs = [KeyedArray(i.*[1,2,3], foo=[:a,:b,:c]) for i in 1:4];
    @test axiskeys(reduce(hcat, vs)) == ([:a,:b,:c], Base.OneTo(4))
    @test axiskeys(reduce(hcat, vs')) == (Base.OneTo(1), [:a,:b,:c,  :a,:b,:c,  :a,:b,:c,  :a,:b,:c])
    @test axiskeys(reduce(vcat, vs)) == ([:a,:b,:c,  :a,:b,:c,  :a,:b,:c,  :a,:b,:c],)

    kvs = wrapdims(vs, bar='a':'d') # add an outer name & keys
    @test axiskeys(reduce(hcat, kvs)) == ([:a,:b,:c], 'a':'d')
    @test axiskeys(reduce(vcat, unname(kvs))) == ([:a,:b,:c,  :a,:b,:c,  :a,:b,:c,  :a,:b,:c],)

    twomats = [wrapdims(rand(2,2), x=10:11, y='a':'b'), wrapdims(rand(2,2), x=10:11, y='c':'d')]
    @test axiskeys(reduce(hcat, twomats)) == (10:11, ['a', 'b', 'c', 'd'])
    @test axiskeys(reduce(vcat, twomats')) == (['a', 'b', 'c', 'd'], 10:11)
    @test_throws ArgumentError axiskeys(reduce(hcat, twomats'))
    @test_throws ArgumentError axiskeys(reduce(vcat, twomats))

    # single argument
    @test dimnames(vcat(V)) == dimnames(cat(V; dims=1)) == (:r,)
    @test axiskeys(vcat(V)) == axiskeys(cat(V; dims=1)) == (['a', 'b', 'c'],)
    @test dimnames(hcat(V)) == dimnames(cat(V; dims=2)) == (:r, :_)
    @test axiskeys(hcat(V)) == axiskeys(cat(V; dims=2)) == (['a', 'b', 'c'], Base.OneTo(1))

    @test dimnames(vcat(M)) == dimnames(cat(M; dims=1)) == (:r, :c)
    @test axiskeys(vcat(M)) == axiskeys(cat(M; dims=1)) == ('a':1:'c', 2:5)

    @test dimnames(hcat(M)) == dimnames(cat(M, dims=2)) == (:r, :c)
    @test axiskeys(hcat(M)) == axiskeys(cat(M, dims=2)) == ('a':1:'c', 2:5)

    @test dimnames(cat(M; dims=3)) == (:r, :c, :_)
    @test axiskeys(cat(M; dims=3)) == ('a':1:'c', 2:5, Base.OneTo(1))
end
@testset "matmul" begin

    # two matrices
    @test axiskeys(M * M') === ('a':'c', 'a':'c')
    @test axiskeys(M * rand(4,5)) === ('a':'c', Base.OneTo(5))
    @test axiskeys(rand(2,3) * M) === (Base.OneTo(2), 2:5)
    @test axiskeys(MN * MN') === ('a':'c', 'a':'c')
    @test axiskeys(M * MN') === ('a':'c', 'a':'c')

    # two vectors
    @test (V' * V) isa Int
    @test (V' * VN) isa Int
    @test (V' * rand(Int, 10)) isa Int
    @test (rand(Int, 10)' * V) isa Int
    @test axiskeys(V * V') === (10:10:100, 10:10:100)
    @test dimnames(V * V') === (:v, :v)
    @test axiskeys(V * VN') === (10:10:100, 10:10:100)
    @test dimnames(V * VN') === (:v, :v)
    @test axiskeys(V * rand(1,10)) === (10:10:100, Base.OneTo(10))
    @test dimnames(V * rand(1,10)) === (:v, :_)

    # matrix * vector
    @test axiskeys(M * M('a')) === ('a':'c',)
    @test dimnames(M * M('a')) === (:r,)
    @test axiskeys(M(5)' * M) === (Base.OneTo(1), 2:5)
    @test dimnames(M(5)' * M) === (:_, :c)

end
@testset "div" begin # doesn't work for names yet

    A = wrapdims(rand(Int8,3,4), 'a':'c', 10:10:40)
    C = wrapdims(rand(Int8,3), ['a', 'b', 'c'])
    D = wrapdims(rand(Int8,4), [10, 20, 30, 40])

    @test axiskeys(A \ A) == (10:10:40, 10:10:40)
    @test axiskeys(A \ C) == (10:10:40,)
    @test axiskeys(A' \ D) == ('a':'c',)

end
@testset "copy etc" begin

    # copy, similar, etc
    @test axiskeys(copy(M)) == ('a':'c', 2:5)
    @test zero(M)('a',2) == 0

    @test axiskeys(similar(M, Int)) == axiskeys(M)
    @test AxisKeys.haskeys(similar(M, Int, 3,3)) == false
    @test dimnames(similar(M, 3,3)) == (:r, :c)
    @test AxisKeys.hasnames(similar(M, 2,2,2)) == false

end
@testset "deleteat!" begin
    kv = wrapdims([1, 2, 3, 4, 5, 6.0], a=[:a, :b, :c, :d, :e, :f])

    @test kv == deleteat!(kv, 1) == KeyedArray([2, 3, 4, 5, 6.0], a=[:b, :c, :d, :e, :f])
    @test kv == deleteat!(kv, 1:2) == KeyedArray([4, 5, 6.0], a=[:d, :e, :f])
    @test kv == deleteat!(kv, (1, 3)) == KeyedArray([5.0], a=[:e])

    # make sure array is not in an invalid state if the deleteat for indices fails
    ka = wrapdims([4, 5, 6.0], a=1:3)
    @test_throws MethodError deleteat!(ka, 2)
    @test ka == KeyedArray([4, 5, 6.0], a=1:3)
end

@testset "equality" begin

    data = parent(parent(M))
    M2 = wrapdims(data, r='a':'c', c=[2,3,4,5]) # same values
    M3 = wrapdims(data, 'a':'c', 2:5) # no names but same keys
    M4 = wrapdims(data, r='a':'c', c=nothing) # missing keys
    @test M == M2 == M3 == M4
    @test isequal(M, M2) && isequal(M, M3) && isequal(M, M4)
    @test M ≈ M2 ≈ M3 ≈ M4

    M5 = wrapdims(data, r='a':'c', c=4:7) # wrong keys
    M6 = wrapdims(data, r='a':'c', nope=2:5) # wrong name
    M7 = wrapdims(2 .* data, r='a':'c', c=2:5) # wrong data
    @test M != M5
    @test M != M6
    @test M != M7
    @test !isapprox(M, M5) && !isapprox(M, M7)

    @test M == MN # order of wrappers
    @test isequal(M, MN)
    @test M ≈ MN

    # Arrays of different sizes
    V = wrapdims(vec(data), r='a':'l')  # vectorised
    A = wrapdims(reshape(data, 2, 2, 3), r=['a','b'], c=[1, 2], l=[:x, :y, :z])  # cube

    @test M != V
    @test M != A
    @test V != A
    @test !isequal(M, V)
    @test !isequal(M, A)
    @test !isequal(V, A)
    @test !isapprox(M, V)
    @test !isapprox(M, A)
    @test !isapprox(V, A)

end

@testset "linalg" begin
    using LinearAlgebra

    # more wrappers -- https://github.com/mcabbott/AxisKeys.jl/issues/69
    @testset "wrappers" begin
        D3 = Diagonal(randn(3))
        U3 = UpperTriangular(rand(3,3))
        U4 = UpperTriangular(rand(4,4) .+ im)
        A3 = rand(10, 3)'
        A10 = rand(3, 10)'
        T3 = transpose(rand(10, 3))
        T10 = transpose(rand(3, 10))

        @test axiskeys(D3 * unname(M), 2) == 2:5
        @test_skip U3 * M # *(::UpperTriangular, ::NamedDimsArray) is ambiguous
        @test axiskeys(U4 * unname(M'), 2) == 'a':'c'
        @test axiskeys(A3 * V, 1) == Base.OneTo(3)
        @test axiskeys(T3 * V, 1) == Base.OneTo(3)

        @test axiskeys(D3 \ M, 2) == 2:5
        @test axiskeys(U3 \ M, 2) == 2:5
        @test_skip U4 / M  # no method matching ldiv!(::NamedDims.NamedFactorization, ::Matrix{ComplexF64})
        @test axiskeys(A10 \ V, 1) == 1:3
        @test axiskeys(T10 \ V, 1) == 1:3
    end

    # Catch issue #133
    S =  wrapdims(Symmetric(rand(Int8,3,3)), 'a':'c', 10:10:30)
    @test LinearAlgebra.copy_oftype(S, eltype(S)) == S

    @testset "cholesky" begin
        A = rand(10, 3)
        ka = KeyedArray(A, (0:9, ["a", "b", "c"]))
        kanda = KeyedArray(A, time=0:9, id=["a", "b", "c"])

        # These should all be equivalent because we aren't wrapping the U and L matrices in
        # the Factorization
        @test cholesky(cor(A)) == cholesky(cor(ka)) == cholesky(cor(kanda))
        @test cholesky(Hermitian(cor(A))) == cholesky(Hermitian(cor(ka))) == cholesky(Hermitian(cor(kanda)))
        @test all(isposdef, (cor(A), cor(ka), cor(kanda)))
    end
end
