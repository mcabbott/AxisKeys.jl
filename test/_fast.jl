using Test, AxisKeys, BenchmarkTools

@testset "indexing & lookup" begin

    A = wrapdims(rand(2,3), 11.0:12.0, [:a, :b, :c])

    # getindex
    @test 0 == @ballocated $A[1, 1]
    @test 272 >= @ballocated $A[1, :]
    @test (@inferred A[1, :]; true)
    @test (@inferred view(A, 1, :); true)

    # getkey
    @test 32 >= @ballocated $A(11.0, :a)

    al_A = @ballocated view($A,1,:) # 96

    @test al_A == @ballocated $A(11.0,:)
    @test al_A == @ballocated $A(11.0)
    @test al_A == @ballocated $A(11)
    @test 0 == @ballocated AxisKeys.inferdim(11, $(axiskeys(A)))
    @test (@inferred A(11); true)
    @test al_A/2 >= @ballocated $A[1,:] .= 0 # dotview skips view of key vector

    # with names
    N = wrapdims(rand(2,3), row=11.0:12.0, col=[:a, :b, :c])

    @test 0 == @ballocated $N[1, 1]
    @test 0 == @ballocated $N[col=1, row=1]
    @test 288 >= @ballocated $N[row=1]
    @test (@inferred N[row=1]; true)

    # extraction
    @test 0 == @ballocated axiskeys($N)
    @test 0 == @ballocated axiskeys($N, 1)
    @test 0 == @ballocated axiskeys($N, :row)

    @test 0 == @ballocated dimnames($N)
    @test 0 == @ballocated dimnames($N, 1)

    @test 0 == @ballocated AxisKeys.hasnames($N)
    @test 0 == @ballocated AxisKeys.haskeys($N)

end
@testset "construction" begin

    M = rand(2,3);

    @test 64 >= @ballocated KeyedArray($M, ('a':'b', 10:10:30))
    @test 16 >= @ballocated NamedDimsArray($M, (:row, :col))
    @test (@inferred KeyedArray(M, ('a':'b', 10:10:30)); true)

    V = rand(3);
    @test 64 >= @ballocated KeyedArray($V, 'a':'c')

    # nested pair via keywords
    @test 80 >= @ballocated KeyedArray($M, row='a':'b', col=10:10:30) # 464 >=
    @test 80 >= @ballocated NamedDimsArray($M, row='a':'b', col=10:10:30) # 400 >=
    @test 560 >= @ballocated wrapdims($M, row='a':'b', col=10:10:30) # 560 >=

    @test (@inferred KeyedArray(M, row='a':'b', col=10:10:30); true)
    @test (@inferred NamedDimsArray(M, row='a':'b', col=10:10:30); true)

end
