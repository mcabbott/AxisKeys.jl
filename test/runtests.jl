using Test, AxisKeys, NamedDims
using Statistics, OffsetArrays, Tables, UniqueVectors, LazyStack

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

end
@testset "fast findfirst & findall" begin

    include("_findrange.jl")

end
