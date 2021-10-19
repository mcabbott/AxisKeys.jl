@testset "chainrules.jl" begin
    function FiniteDifferences.to_vec(k::KeyedArray)
        v, b = to_vec(k.data)
        back(x) = KeyedArray(b(x); AxisKeys.named_axiskeys(k)...)
        return v, back
    end
    test_rrule(AxisKeys.keyless_unname, KeyedArray(ones(3), a=1:3); check_inferred=false)
    test_rrule(AxisKeys.keyless_unname, KeyedArray(ones(3, 4), a=1:3, b='a':'d'); check_inferred=false)
    test_rrule(AxisKeys.keyless_unname, KeyedArray(ones(3), a=1:3); output_tangent=rand(3, 1), check_inferred=false)
end
