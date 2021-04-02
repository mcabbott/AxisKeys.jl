
#=
Simple support for FFTs using:
https://github.com/JuliaMath/AbstractFFTs.jl

Does not (yet) cover plan_fft & friends,
because extracting the dimensions from those is tricky
=#

using AbstractFFTs

for fun in [:fft, :ifft, :bfft, :rfft]
    @eval function AbstractFFTs.$fun(A::Union{KeyedArray,NdaKa}, dims = ntuple(+,ndims(A)))
        numerical_dims = NamedDims.dim(A, dims)
        data = $fun(keyless(A), numerical_dims)
        keys = fft_keys($fun, A, numerical_dims, data)
        KeyedArray(data, keys)
    end
end

function AbstractFFTs.irfft(A::Union{KeyedArray,NdaKa}, len::Integer, dims = ntuple(+,ndims(A)))
    numerical_dims = NamedDims.dim(A, dims)
    data = irfft(keyless(A), len, numerical_dims)
    keys = fft_keys(irfft, A, numerical_dims, data)
    KeyedArray(data, keys)
end

for shift in [:fftshift, :ifftshift]
    @eval function AbstractFFTs.$shift(A::Union{KeyedArray,NdaKa}, dims = ntuple(+,ndims(A)))
        numerical_dims = NamedDims.dim(A, dims)
        data = $shift(keyless(A), numerical_dims)
        keys = ntuple(ndims(A)) do d
            k = axiskeys(A,d)
            d in numerical_dims || return k
            $shift(k)
        end
        KeyedArray(data, keys)
    end
end

# copy(fftfreq(10, 1)) isa Vector # perhaps that needs a method:
# Base.copy(x::Frequencies{<:Number}) = x  # fixed in AbstractFFts 1.0

fft_keys(f, A, dims, B) = ntuple(ndims(A)) do d
        k = axiskeys(A,d)
        d in dims || return k
        if k isa Frequencies
            return fft_un_freq(k)
        elseif k isa AbstractRange{<:Number}
            return fftfreq(length(k), inv(step(k)))
        end
        return k
    end

fft_keys(::typeof(rfft), A, dims, B) = ntuple(ndims(A)) do d
        k = axiskeys(A,d)
        d in dims || return k
        if k isa Frequencies || k isa AbstractRange{<:Number}
            return rfftfreq(length(k), inv(step(k)))
        end
        return axes(B,d)
    end

fft_keys(::typeof(irfft), A, dims, B) = ntuple(ndims(A)) do d
        k = axiskeys(A,d)
        d in dims || return k
        if k isa Frequencies || k isa AbstractRange{<:Number}
            return irfft_un_freq(k, size(B,d))
        end
        return axes(B,d)
    end

# This just chooses a nicer zero when inverting FFT:
function fft_un_freq(x::Frequencies)
    s = inv(x.multiplier * x.n)
    range(zero(s), step = s, length = x.n)
end

function irfft_un_freq(x, len)
    s = inv(step(x) * len)
    range(zero(s), step = s, length = len)
end
