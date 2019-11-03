@testset "filter" begin

    @test AxisRanges.filter(iseven, (1,2,3,4)) === (2,4)
    if VERSION >= v"1.2" # fails on 1.0
        @test 0 == @allocated AxisRanges.filter(iseven, (1,2,3,4))
    end

end
@testset "Tuple" begin

    @test AxisRanges._Tuple((1,2)) === (1,2)
    @test AxisRanges._Tuple(Ref(3)) === (3,)
    @test 0 == @allocated AxisRanges._Tuple(Ref(3))

end
@testset "map" begin

    @test AxisRanges.map(sqrt, Ref(4))[] == 2.0
    @test AxisRanges.map(sqrt, Ref(4)) isa Ref

    @test AxisRanges.map(+, Ref(2), (3,))[] == 5
    @test AxisRanges.map(+, Ref(2), (3,)) isa Ref
    @test AxisRanges.map(+, (2,), Ref(3)) isa Ref
    @test 0 == @allocated AxisRanges.map(+, (2,), Ref(3))

end
if VERSION >= v"1.2" # <(3) doesn't exist on 1.1, but Base.Fix2 is fine
@testset "unit ranges" begin

    for r in (Base.OneTo(5), 2:5)
        for x in -2:7

            @test AxisRanges.findfirst(==(x), r) == findfirst(==(x), collect(r))
            @test AxisRanges.findfirst(isequal(x), r) == findfirst(isequal(x), collect(r))

            for op in (isequal, Base.:(==), Base.:<, Base.:<=, Base.:>, Base.:>=)

                @test AxisRanges.findall(op(x), r) == Base.findall(op(x), collect(r))
                @test AxisRanges.findall(op(x), r) isa AbstractRange
                T = typeof(@inferred AxisRanges.findall(op(x), r))
                T <: AbstractRange || @info "$op($x) $r  -> $T"
            end
        end
    end

end
@testset "step ranges" begin

    for op in (Base.:<=, Base.:>, )# Base.:<)

        for r in (0:3:9, )# 0.5:0.5:8) # stepranges?
        for x in [-0.1, 0, 0.2, 0.5, 0.7, 1.0, 1.2,  1.9, 2.0, 2.1, 7.9, 8, 8.1, 7.9, 8, 8.1]

            @test AxisRanges.findall(op(x), r) == Base.findall(op(x), collect(r))
            T = typeof(AxisRanges.findall(op(x), r))
            T <: AbstractRange || @info "$op($x) $r  -> $T"
        end
        end

        for r in ('b':'e', 'b':2:'f')
        for x in 'a':'g'

            @test AxisRanges.findall(op(x), r) == Base.findall(op(x), collect(r))
            T = typeof(@inferred AxisRanges.findall(op(x), r))
            T <: AbstractRange || @info "$op($x) $r  -> $T"
        end
        end

    end

end
end # VERSION
