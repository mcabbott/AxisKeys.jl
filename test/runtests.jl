using Test, AxisKeys, NamedDims
using Statistics, OffsetArrays, Tables, UniqueVectors, LazyStack

@testset "wrapdims with $outside outside" for outside in [:NamedDimsArray, :KeyedArray]

    AxisKeys.OUTER[] = outside

    include("_basic.jl")

    include("_functions.jl")

    include("_fast.jl")

    include("_packages.jl")

end
@testset "fast findfirst & findall" begin

    include("_notpiracy.jl")

end
