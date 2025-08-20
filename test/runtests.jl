using Test, AxisKeys, NamedDims
using Statistics, OffsetArrays, Tables, UniqueVectors
using ChainRulesCore: ProjectTo, NoTangent
using ChainRulesTestUtils: test_rrule
using FiniteDifferences

@testset "wrapdims with $outside outside" for outside in [:NamedDimsArray, :KeyedArray]

    if outside == :NamedDimsArray
        AxisKeys.nameouter() = true
    else
        AxisKeys.nameouter() = false
    end

    include("_basic.jl")

    include("_functions.jl")

    include("_fast.jl")

    include("_packages.jl")

    include("_chainrules.jl")

end
@testset "fast findfirst & findall" begin

    include("_findrange.jl")

end

@testset "Interpolations" begin
    using Interpolations
    using StaticArrays

    @testset for (A, it) in Any[
        KeyedArray([1 2 3; 4 5 6], a=-1:0, b=1:3) => BSpline(Linear()),
        KeyedArray([3 2 1; 6 5 4], a=-1:0, b=3:-1:1) => BSpline(Linear()),
        KeyedArray([1 2 3; 4 5 6], a=-1:0, b=1:3) => Gridded(Linear()),
        KeyedArray([3 2 1; 6 5 4], a=-1:0, b=3:-1:1) => Gridded(Linear()),
        KeyedArray([1 2 4; 4 5 7], a=-1:0, b=[1,2,4]) => Gridded(Linear()),
    ]
        @testset for Ai in [interpolate(A, it), linear_interpolation(A)]
            @test issetequal(dimnames(Ai), dimnames(A))
            @test map(sort, named_axiskeys(Ai)) == map(sort, named_axiskeys(A))

            @test Ai(0, 2) == 5.0
            @test Ai((0, 2)) == 5.0
            @test Ai(SVector(0, 2)) == 5.0
            @test Ai(a=0, b=2) == A(a=0, b=2) == 5.0
            @test Ai(a=-0.4, b=2) ≈ 3.8
            @test Ai(a=-0.4, b=2.5) ≈ 4.3
            @test Ai(b=2, a=-0.4) ≈ 3.8
            @test_throws BoundsError Ai(a=0.5, b=2)

            @test Interpolations.gradient(Ai, a=0, b=2) == [3, 1]
            @test_throws ArgumentError Interpolations.gradient(Ai, (b=2, a=0))
        end

        @testset for Aie in [extrapolate(interpolate(A, it), Flat()), linear_interpolation(A; extrapolation_bc=Flat())]
            @test issetequal(dimnames(Aie), dimnames(A))
            @test map(sort, named_axiskeys(Aie)) == map(sort, named_axiskeys(A))

            @test Aie(0, 2) == 5.0
            @test Aie((0, 2)) == 5.0
            @test Aie(SVector(0, 2)) == 5.0
            @test Aie(a=0, b=2) == 5.0
            @test Aie(a=-0.4, b=2) ≈ 3.8
            @test Aie(a=-0.4, b=2.5) ≈ 4.3
            @test Aie(a=0.5, b=2) == 5.0
            @test Aie(b=2, a=-0.4) ≈ 3.8

            @test Interpolations.gradient(Aie, a=0, b=2) == [3, 1]
            @test_throws ArgumentError Interpolations.gradient(Aie, (b=2, a=0))
        end
    end
end

@testset "ambiguities" begin

    @test isempty(detect_unbound_args(AxisKeys))
    alist = detect_ambiguities(AxisKeys, Base)
    @test_broken isempty(alist)

end
