using Test, AxisKeys, NamedDims
using Statistics, OffsetArrays, Tables, UniqueVectors, LazyStack

@testset "wrapdims with $out outside" for out in [:NamedDimsArray, :KeyedArray]

    AxisKeys.OUTER[] = out

    include("_basic.jl")

    include("_functions.jl")

    include("_packages.jl")

end
@testset "fast findfirst & findall" begin

    include("_notpiracy.jl")

end
