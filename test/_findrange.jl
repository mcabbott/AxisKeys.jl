using Test, AxisKeys

if VERSION >= v"1.2" # <(3) doesn't exist on 1.1, but Base.Fix2 is fine
@testset "unit ranges" begin # now methods of AxisKeys.findindex, not Base.findfirst etc.

    for r in (Base.OneTo(5), 2:5)
        for x in -2:7

            @test AxisKeys.findindex(x, r) == findfirst(==(x), collect(r))

            for op in (isequal, Base.:(==), Base.:<, Base.:<=, Base.:>, Base.:>=)

                @test AxisKeys.findindex(op(x), r) == Base.findall(op(x), collect(r))
                @test AxisKeys.findindex(op(x), r) isa AbstractRange
                T = typeof(@inferred AxisKeys.findindex(op(x), r))
                T <: AbstractRange || @info "findindex($op($x), $r) isa $T, unit ranges"
            end
        end
    end

end
@testset "step ranges" begin # now methods of AxisKeys.findindex, not Base.finall

    for op in (Base.:<=, Base.:>, )# Base.:<)

        for r in (0:3:9, )# 0.5:0.5:8) # stepranges?
        for x in [-0.1, 0, 0.2, 0.5, 0.7, 1.0, 1.2,  1.9, 2.0, 2.1, 7.9, 8, 8.1, 7.9, 8, 8.1]

            @test AxisKeys.findindex(op(x), r) == Base.findall(op(x), collect(r))
            T = typeof(AxisKeys.findindex(op(x), r))
            T <: AbstractRange || @info "findindex($op($x), $r) isa $T, step ranges"
        end
        end

        for r in ('b':'e', 'b':2:'f')
        for x in 'a':'g'

            @test AxisKeys.findindex(op(x), r) == Base.findall(op(x), collect(r))
            T = typeof(@inferred AxisKeys.findindex(op(x), r))
            T <: AbstractRange || @info "findindex($op($x), $r) isa $T, step ranges of Char"
        end
        end

    end

end
end # VERSION
