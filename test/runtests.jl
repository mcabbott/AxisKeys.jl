using Test, AxisKeys, NamedDims
using Statistics, OffsetArrays, Tables, UniqueVectors, LazyStack
using ChainRulesCore: ProjectTo
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
@testset "ambiguities" begin

    @test isempty(detect_unbound_args(AxisKeys))
    alist = detect_ambiguities(AxisKeys, Base)
    @test_broken isempty(alist)

end
