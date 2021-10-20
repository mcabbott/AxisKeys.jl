@testset "chainrules.jl" begin

    function FiniteDifferences.to_vec(k::AxisKeys.KaNda)
        v, b = to_vec(k.data)
        back(x) = wrapdims(b(x); AxisKeys.named_axiskeys(k)...)
        return v, back
    end

    function FiniteDifferences.to_vec(k::KeyedArray)
        v, b = to_vec(k.data)
        back(x) = wrapdims(b(x), axiskeys(k)...)
        return v, back
    end

    @testset "KeyedVector" begin
        data = rand(3)
        test_rrule(AxisKeys.keyless_unname, wrapdims(data, a=1:3); check_inferred=false)
        test_rrule(AxisKeys.keyless_unname, wrapdims(data, 1:3); check_inferred=false)
        test_rrule(AxisKeys.keyless_unname, data; check_inferred=false)

        # with matrix output tangent
        test_rrule(AxisKeys.keyless_unname, wrapdims(data, a=1:3); output_tangent=rand(3, 1), check_inferred=false)
        test_rrule(AxisKeys.keyless_unname, wrapdims(data, 1:3); output_tangent=rand(3, 1), check_inferred=false)
        test_rrule(AxisKeys.keyless_unname, data; output_tangent=rand(3, 1), check_inferred=false)
    end

    @testset "KeyedMatrix" begin
        data = rand(3, 4)
        test_rrule(AxisKeys.keyless_unname, wrapdims(data, a=1:3, b='a':'d'); check_inferred=false)
        test_rrule(AxisKeys.keyless_unname, wrapdims(data, 1:3, 'a':'d'); check_inferred=false)
        test_rrule(AxisKeys.keyless_unname, data; check_inferred=false)
    end

end
