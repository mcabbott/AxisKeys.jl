using Test, AxisKeys
using OffsetArrays, UniqueVectors, Tables, LazyStack, Dates, InvertedIndices, FFTW

@testset "offset" begin

    o = OffsetArray(rand(1:99, 5), -2:2)
    w = wrapdims(o, i='a':'e')
    @test axiskeys(w,1) isa OffsetArray
    @test w[i=-2] == w('a')
    @test_throws ArgumentError KeyedArray(o, i='a':'e')

    w′ = wrapdims(o)
    @test axiskeys(w′,1) == -2:2

end
@testset "unique" begin

    u = wrapdims(rand(Int8,5,1), UniqueVector, [:a, :b, :c, :d, :e], nothing)
    @test axiskeys(u,1) isa UniqueVector
    @test u(:b) == u[2,:]

    n = wrapdims(rand(2,100), UniqueVector, x=nothing, y=rand(Int,100))
    @test axiskeys(n,1) isa UniqueVector
    k = axiskeys(n, :y)[7]
    @test n(y=k) == n[:,7]

end
@testset "tables" begin

    R = wrapdims(rand(2,3), 11:12, 21:23)
    N = wrapdims(rand(2,3), a=[11, 12], b=[21, 22, 23.0])

    @test keys(first(Tables.rows(R))) == (:dim_1, :dim_2, :value)
    @test keys(first(Tables.rows(N))) == (:a, :b, :value)

    @test Tables.columns(N).a == [11, 12, 11, 12, 11, 12]

end
@testset "stack" begin

    rin = [wrapdims(1:3, a='a':'c') for i=1:4]

    @test axiskeys(stack(rin), :a) == 'a':'c'
    @test axiskeys(stack(:b, rin...), :a) == 'a':'c' # tuple
    @test axiskeys(stack(z for z in rin), :a) == 'a':'c' # generator

    rout = wrapdims([[1,2], [3,4]], b=10:11)
    @test axiskeys(stack(rout), :b) == 10:11

    rboth = wrapdims(rin, b=10:13)
    @test axiskeys(stack(rboth), :a) == 'a':'c'
    @test axiskeys(stack(rboth), :b) == 10:13

    nts = [(i=i, j="j", k=33) for i=1:3]
    @test axiskeys(stack(nts), 1) == [:i, :j, :k]
    @test axiskeys(stack(:z, nts...), 1) == [:i, :j, :k]
    @test axiskeys(stack(n for n in nts), 1) == [:i, :j, :k]

end
@testset "dates" begin

    D = wrapdims(rand(2,53), row = [:one, :two], week = Date(2020):Week(1):Date(2021))
    w9 = axiskeys(D,:week)[9]
    @test w9 isa Date
    @test D(w9) == D[week=9]
    # But steps of Year(1) don't work, https://github.com/JuliaLang/julia/issues/35203

    @test D(==(Date(2020, 1, 8))) == D[:, 2:2]
    @test D(Near(Date(2020, 1, 10))) == D(Date(2020, 1, 8)) == D[:, 2]
    @test D(Interval(Date(2020, 1, 8), Date(2020, 1, 22))) == D[:, 2:4]

end
@testset "inverted" begin

    K = wrapdims(rand(4,5))
    @test K[:, Not(4)] == K[:, vcat(1:3, 5)] == K(:, Base.Fix2(!=,4))
    @test K[Not(1,4), :] == K[2:3, :] == K(r -> 2<=r<=3, :)

    N = wrapdims(rand(Int8, 2,3,4), a=[:one, :two], b='α':'γ', c=31:34)
    @test N[b=Not(2)] == N[:,[1,3],:] == N(b=Base.Fix2(!=,'β')) == N(:,['α','γ'],:)
    @test N[c=Not(2,4)] == N(c=Index[Not(2,4)])

end
@testset "FFT" begin

    times = 0.1:0.1:10
    data = rand(100) ./ 10; data[1:5:end] .= 1;
    A = KeyedArray(data, times)
    Atil = fft(A)
    @test axiskeys(Atil,1)[end] == -0.1

    Ashift = fftshift(Atil)
    @test axiskeys(Ashift,1)[end] == +4.9

    Ar = rfft(A) # different size, different freqencies
    @test axiskeys(Ar,1)[end] == 5.0

    A2 = ifft(ifftshift(Ashift))
    A ≈ A2
    @test all(mod.(axiskeys(A,1) .- axiskeys(A2,1),10) .≈ 0.1) # that's OK I think?

    data2 = randn(32,2);
    B = wrapdims(data2, time=100:10:410.0, col=[:a, :b])
    @test_skip Btil = fftshift(fft(B, :time), :time) # result does not have names
    Btil = fftshift(fft(B, :time), 1)
    @test parent(Btil) ≈ fftshift(fft(data2,1),1)

end







#=
using FFTW, Unitful, Plots, UnitfulRecipes
using Unitful: s

times = 0.1s:0.1s:10s
data = rand(100) ./ 10; data[1:5:end] .= 1;
# data = zeros(100) .* 1mV; data[1:5:end] .= 1mV; # MethodError: no method matching plan_fft(::Array{Quantity{Float64,𝐋²*𝐌*𝐈⁻¹*𝐓⁻³ ...

# plot(ustrip(times), data)
plot(times, data)

fft(data)

freqs = fftfreq(length(times), 1/step(times)) # better!

fftfreq(freqs)

# plot(ustrip(freqs) , abs2.(fft(data)))
plot(freqs , abs2.(fft(data))) # DimensionError: Inf and 0.0 s are not dimensionally compatible.

using AxisKeys, AbstractFFTs
using AxisKeys: keyless


kd = KeyedArray(data, times)

abs.(fft(kd)) # broadcasting is collecting the keys to a vector here?

fftshift(ans)

data2 = rand(100,2) ./ 10; data2[1:5:end, 1] .= 1; data2[3:7:end, 2] .= 1;
kd2 = KeyedArray(data2, (times, [:a, :b]))

fftshift(fft(kd2, 1),1)




fr = fftfreq(10, 1)
dump(fr)
fftshift(fr)
typeof(ans)

fr = fftfreq(10, inv(1s))
fftshift(fr) # is a steprange, good




using Plots, Unitful
using Unitful: s

times = 0.1s:0.1s:10s
data = rand(100) ./ 10; data[1:5:end] .= 1;

plot(ustrip(times), data)
plot(times, data) # DimensionError: Inf and 0.1 s are not dimensionally compatible.
# isless(::Quantity{Float64,NoDims,Unitful.FreeUnits{(),NoDims,nothing}}, ::Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}}) at /Users/me/.julia/packages/Unitful/PZjMS/src/quantities.jl:231

=#

