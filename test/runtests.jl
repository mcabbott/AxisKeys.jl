using Test, AxisRanges, NamedDims
using Statistics, OffsetArrays, Tables

# AxisRanges.OUTER[] = :nda # changes behaviour of wrapdims

include("_basic.jl")

include("_functions.jl")

include("_notpiracy.jl")

@testset "offset" begin

    o = OffsetArray(rand(1:99, 5), -2:2)
    w = wrapdims(o, i='a':'e')
    @test ranges(w,1) isa OffsetArray
    @test w[i=-2] == w('a')

end
@testset "tables" begin

    R = wrapdims(rand(2,3), 11:12, 21:23)
    N = wrapdims(rand(2,3), a=[11, 12], b=[21, 22, 23.0])

    @test keys(first(Tables.rows(R))) == (:dim_1, :dim_2, :value)
    @test keys(first(Tables.rows(N))) == (:a, :b, :value) # fails with nda(ra(...))

    @test Tables.columns(N).a == [11, 12, 11, 12, 11, 12] # fails with nda(ra(...))

end
