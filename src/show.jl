
Base.summary(io::IO, x::RangeArray) = _summary(io, x)
Base.summary(io::IO, A::NamedDimsArray{L,T,N,<:RangeArray}) where {L,T,N} = _summary(io, A)

function _summary(io, x)
    print(io, ndims(x), "-dimensional ")
    showtype(io, x)
    println(io, " with range", ndims(x)>1 ? "s:" : ":")
    for d in 1:ndims(x)
        print(io, d==1 ? "↓" : d==2 ? "→" : "□", "   ")
        c = colour(x, d)
        hasnames(x) && printstyled(io, names(x,d), " ∈ ", color=c)
        printstyled(io, length(ranges(x,d)), "-element ", shorttype(ranges(x,d)), "\n", color=c)
    end
    print(io, "And data, ", summary(rangeless(unname(x))))
    if ndims(x)==1 && length(ranges_or_axes(x, 1)) != length(x)
        throw(ArgumentError("length of range, $(length(ranges_or_axes(x, 1))), must match length of vector, $(length(x))! "))
    end
end

shorttype(r::Vector{T}) where {T} = "Vector{$T}"
shorttype(r::OneTo) where {T} = "OneTo{Int}"
shorttype(r::SubArray) = "view(::" * shorttype(parent(r)) * ",...)"
shorttype(r::OffsetArray) = "OffsetArray(::" * shorttype(parent(r)) * ",...)"
function shorttype(r)
    bits = split(string(typeof(r)),',')
    length(bits) == 1 && return bits[1]
    bits[1] * ",...}"
end

showtype(io::IO, ::RangeArray) =
    print(io, "RangeArray(...)")
showtype(io::IO, ::RangeArray{T,N,<:NamedDimsArray}) where {T,N} =
    print(io, "RangeArray(NamedDimsArray(...))")
showtype(io::IO, ::NamedDimsArray{L,T,N,<:RangeArray}) where {L,T,N} =
    print(io, "NamedDimsArray(RangeArray(...))")

function colour(A::AbstractArray, d::Int)
    ranges_or_axes(A,d) === OneTo(1) && return :light_black
    colour(A, eltype(ranges_or_axes(A,d)))
end
function colour(A::AbstractArray, dims)
    all(d -> ranges_or_axes(A,d) === OneTo(1), dims) && return :light_black
    colour(A, promote_type(map(d -> eltype(ranges_or_axes(A,d)), dims)...))
end
function colour(A::AbstractArray, T::Type)
    T <: AbstractFloat && return :cyan
    T <: Number && return :blue
    T <: AbstractString && return :yellow #:green
    T <: AbstractChar  && return :yellow
    T <: Symbol && return :magenta
    :red
end

#=
using AxisRanges, OffsetArrays

A = wrapdims(rand(20), r='a':'t')
C = wrapdims(rand(4,200), r='a':'d', col=10:10:2000)
C'
D = wrapdims(100 .* rand(4,20,3), r=[:a, :b, :c, :d], col=1:2:40, page=1:3)
permutedims(D, (3,1,2))
E = wrapdims(rand(3,6), alpha=["one", "two", "three"], beta='A':'F')
E′ = wrapdims(OffsetArray(rand(3,6), 10,20), alpha=["one", "two", "three"], beta='A':'F')
F = wrapdims(ones(10,10,1,10), a='α':'κ', b=1:10.0, c=nothing, d=nothing)#'A':'J')
sum(F, dims=(:b,:c))

=#

# Print ranges as extra rows/cols appended to vec/matrix, or each slice of hihger-dim:

Base.print_matrix(io::IO, A::RangeArray) = range_print_matrix(io, A, true)
Base.print_matrix(io::IO, A::NdaRa) = range_print_matrix(io, A, true)

function range_print_matrix(io::IO, A, reduce_size::Bool=false)
    if reduce_size # not applied when called from show_nd
        io = IOContext(io, :displaysize => displaysize(io) .- (3+ndims(A), 0))
    end

    h, w = displaysize(io)
    # If the matrix has millions of rows, avoid making huge ::Any array
    ind1 = size(A,1) < h ? Colon() : vcat(1:(h÷2), size(A,1)-(h÷2):size(A,1))
    wn = w÷3 # integers take 3 columns each when printed, floats more
    ind2 = size(A,2) < wn ? Colon() : vcat(1:(wn÷2), (wn÷2)+1:size(A,2))

    fakearray = hcat(
        ShowWith.(no_offset(ranges(A,1))[ind1]; color=colour(A,1)),
        getindex(no_offset(unname(rangeless(A))), ind1, ind2)
        )
    if ndims(A) == 2
        toprow = vcat(
            ShowWith(0, hide=true),
            ShowWith.(no_offset(ranges(A,2))[ind2]; color=colour(A,2))
            )
        fakearray = vcat(permutedims(toprow), fakearray)
    end
    Base.print_matrix(io, fakearray)
end

no_offset(x) = x
no_offset(x::OffsetArray) = parent(x)

# Figure out how to add colour without messing up spacing / style:

struct ShowWith{T,NT} <: AbstractString
    val::T
    hide::Bool
    nt::NT
    ShowWith(val; hide::Bool=false, kw...) =
        new{typeof(val),typeof(kw.data)}(val, hide, kw.data)
end
function Base.show(io::IO, x::ShowWith; kw...)
    s0 = sprint(show, x.val; context=io, kw...)
    s = string('(', s0, ')')
    if x.hide
        printstyled(io, " "^length(s); x.nt...)
    else
        printstyled(io, s; x.nt...)
    end
end
Base.alignment(io::IO, x::ShowWith) =  alignment(io, x.val) .+ (2,0) # extra brackets
Base.length(x::ShowWith) = length(string(x.val))
Base.print(io::IO, x::ShowWith) = printstyled(io, string(x.val); x.nt...)

# For higher-dim printing, I just want change the [:, :, 1] things, add name/key,
# but can't see a way to hook in. So copy this huge function from Base?
# Also, let me change it to print fewer pannels...

using Base: tail, print_matrix, printstyled, alignment

function Base.show_nd(io::IO, A::Union{RangeArray, NamedDimsArray}, print_matrix::Function, label_slices::Bool)
    f = hasranges(A) ? range_print_matrix : Base.print_matrix
    limit = get(io, :limit, false)
    if limit
        limited_show_nd(io, A, f, label_slices)
    else
        Core.invoke(Base.show_nd, Tuple{IO, AbstractArray, Function, Bool}, io, A, f, label_slices)
    end
end

# julia> methods(Base.show_nd)
# [1] show_nd(io::IO, a::AbstractArray, print_matrix::Function, label_slices::Bool) in Base at arrayshow.jl:257

function limited_show_nd(io::IO, a::AbstractArray, print_matrix::Function, label_slices::Bool)
    isempty(a) && return
    tailinds = tail(tail(axes(a)))
    nd = ndims(a)-2

    # Pick a colour for slice labels:
    c3 = colour(a, 3:ndims(a))

    # If there are many slices, and they can't all fit, then we will print just 3
    if prod(length, tailinds) > 3 && (2+size(a,1)) * prod(length, tailinds) >  displaysize(io)[1]
        midI = CartesianIndex(map(ax -> ax[firstindex(ax) + length(ax)÷2], tailinds))
        fewpanels = [CartesianIndex(first.(tailinds)), midI, CartesianIndex(last.(tailinds)) ]
        printstyled(io, "[showing 3 of $(prod(length, tailinds)) slices]\n", color=c3)
    else
        fewpanels = CartesianIndices(tailinds)
    end

    # Given how many we're printing, adjust the size allocated to each
    top = hasranges(a) ? 3+ndims(a) : 0 # same as in range_print_matrix, but do it once.
    if length(fewpanels) > 1
        displayheight = max(13, (displaysize(io)[1]-top) ÷ length(fewpanels))
    else
        displayheight = displaysize(io)[1]-top
    end
    io = IOContext(io, :displaysize => (displayheight, displaysize(io)[2]))

    for I in fewpanels
        idxs = I.I
        if label_slices
            printstyled(io, "[:, :", color=c3)
            for i = 1:nd
                if hasnames(a) && !hasranges(a)
                    name = names(a, i+2)
                    printstyled(io, ", $name=$(idxs[i])", color=c3)
                else
                    printstyled(io, ", $(idxs[i])", color=c3)
                end
            end
            if !hasranges(a)
                printstyled(io, "]", color=c3) # done! I forgot \n here, but prefer this.
            else
                printstyled(io, "] ~ (:, :", color=c3)
                for i = 1:nd
                    key = sprint(show, ranges(a, i+2)[idxs[i]], context=io)
                    # if hasnames(a)
                    #     name = names(a, i+2)
                    #     printstyled(io, ", $name = $key", color=c3)
                    # else
                        printstyled(io, ", $key", color=c3)
                    # end
                end
                printstyled(io, "):\n", color=c3)
            end
        end
        slice = view(a, axes(a,1), axes(a,2), idxs...)
        print_matrix(io, slice)
        print(io, idxs == map(last,tailinds) ? "" : "\n\n")
    end
end

# Piracy to make NamedDimsArrays equally pretty
# showarg(..., false) shortens the printing for this:
# NamedDimsArray(OffsetArray(rand(2,3), 10,20), (:row, :col))

function Base.summary(io::IO, A::NamedDimsArray)
    print(io, Base.dims2string(size(A)), " NamedDimsArray(")
    Base.showarg(io, parent(A), false)
    print(io, ", ", names(A), ")")
end

function Base.print_matrix(io::IO, A::NamedDimsArray)
    s1 = string("↓ ", names(A,1)) * "  "
    if ndims(A)==2
        s2 = string(" "^length(s1), "→ ", names(A,2), "\n")
        printstyled(io, s2, color=:magenta)
    end
    ioc = IOContext(io, :displaysize => displaysize(io) .- (2, 0))
    Base.print_matrix(ioc, parent(A), ShowWith(s1, color=:magenta))
end

#=
# A hack to avoid big messy function?

function Base.print_array(io::IO, A::NamedDimsArray{L,T,3}) where {L,T}
    s3 = string("[", names(A,3), " ⤋ ]")
    printstyled(io, s3, color=:magenta)
    Base.show_nd(io, A, Base.print_matrix, true)
end
function Base.print_array(io::IO, A::NamedDimsArray{L,T,4}) where {L,T}
    s3 = string("[", names(A,3),", ", names(A,4), " ⤋ ]")
    printstyled(io, s3, color=:magenta)
    Base.show_nd(io, A, Base.print_matrix, true)
end

=#
