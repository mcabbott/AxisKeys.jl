
#=
Simple support for FFTs using:
https://github.com/JuliaMath/AbstractFFTs.jl

Does not (yet) cover plan_fft & friends,
because extracting the dimensions from those is tricky
=#

using AbstractFFTs

for fun in [:fft, :ifft, :bfft, :rfft,]
    freq = fun == :rfft ? :rfftfreq : :fftfreq
    @eval function AbstractFFTs.$fun(A::Union{KeyedArray,NdaKa}, dims = ntuple(+,ndims(A)))
        numerical_dims = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
        data = AbstractFFTs.$fun(keyless(A), numerical_dims)
        keys = ntuple(ndims(A)) do d
            k = axiskeys(A,d)
            d in numerical_dims || return k
            k isa AbstractRange{<:Number} || k isa AbstractFFTs.Frequencies || return k
            # eltype(k) <: Integer && return k
            AbstractFFTs.$freq(length(k), inv(step(k)))
        end
        KeyedArray(data, keys)
    end
end

for shift in [:fftshift, :ifftshift]
    @eval function AbstractFFTs.$shift(A::Union{KeyedArray,NdaKa}, dims = ntuple(+,ndims(A)))
        numerical_dims = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
        data = AbstractFFTs.$shift(keyless(A), numerical_dims)
        keys = ntuple(ndims(A)) do d
            k = axiskeys(A,d)
            d in numerical_dims || return k
            AbstractFFTs.$shift(k)
        end
        KeyedArray(data, keys)
    end
end

