
Base.summary(io::IO, x::RangeArray) = _summary(io, x)
Base.summary(io::IO, A::NamedDimsArray{L,T,N,<:RangeArray}) where {L,T,N} = _summary(io, A)

function _summary(io, x)
    print(io, ndims(x), "-dimensional ")
    showtype(io, x)
    println(io, " with range", ndims(x)>1 ? "s:" : ":")
    for d in 1:ndims(x)
        r = sprint(show, ranges(x,d); context=IOContext(io, :limit=>true, :compact=>true, :displaysize=>(1,10))) # this doesn't help!
        c = colour(x, d)
        if hasnames(x)
            # println(io, "  ", names(x,d), " ∈ ", ranges(x,d))
            printstyled(io, "  ", names(x,d), " = ", r, "\n", color=c)
        else
            # println(io, "  (", d, ") ∈ ", ranges(x,d))
            printstyled(io, "  (", d, ") = ", r, "\n", color=c)
        end
    end
    print(io, "And data, ", summary(rangeless(unname(x))))
end

# Now I want a set of distinguishable and not-ugly colours.
# When there are no names, I will use the first three:

COLOURS = Union{Symbol,Int}[:blue, :green, :magenta, # first three used when no names
    :blue, :cyan, :red, :yellow,
    # :light_blue, :light_green, :light_magenta,
    # :light_red, # :light_yellow, :light_cyan, # removed
    ] |> unique!
#=

for c in sort(AxisRanges.COLOURS, by=reverse∘string)
    printstyled(stdout, c, "\n", color=c)
end

=#

# Idea number 1, hash the names & use that. But there will be collisions.

# function getcolour(n)
#     isempty(COLOURS) && append!(COLOURS, [:blue, :green, :magenta, :cyan, :red])
#     n === :_ && return :light_black # :default #:white # :light_black
#     if n isa Int && n in eachindex(COLOURS)
#         return COLOURS[n]
#     else
#         i = mod1(hash(n), length(COLOURS))
#         return COLOURS[i]
#     end
# end
# getcolour(A::AbstractArray, d) = hasnames(A) ? getcolour(names(A,d)) : getcolour(d)

# Idea number 2, you could also just step through them globally, building a dict of
# what names have been seen.
#=
CDICT = Dict()
CNUM = Ref(1)
function getcolour(n)
    isempty(COLOURS) && append!(COLOURS, [:blue, :green, :magenta, :cyan, :red])
    n === :_ && return :light_black
    if n isa Int && n in eachindex(COLOURS)
        return COLOURS[n]
    else
        get!(CDICT, n) do
            CNUM[] = mod1(CNUM[] + 1, length(COLOURS))
            c = COLOURS[CNUM[]]
            # If you had the array, you could here insert a check that
            # tries not to pick the same as other names...
        end
    end
end
=#
# New version:
#=
"""
    colour(A, d)

This returns a colour like `:red` for this dimension.

If `A` has names, then the colour used for `names(A,d)` is saved globally,
and re-used if seen on any other array. When picking a new colour, it attempts
to avoid names already associated with other dimensions of `A`.

To disable all of this, `empty!(AxisRanges.COLOURS)`.
"""
function colour(A::AbstractArray, d)
    isempty(COLOURS) && return :normal
    length(COLOURS) == 1 && return COLOURS[1]

    if !hasnames(A)
        if axes(A,d) === OneTo(1)
            return CDICT[:_]
        else
            return COLOURS[mod1(d, length(COLOURS))]
        end
    end

    n = names(A,d)
    get!(CDICT, n) do
        # if not found...
        CNUM[] = mod1(CNUM[] + 1, length(COLOURS)) # by default pick the next in sequence
        c = COLOURS[CNUM[]]                        # candidate colour.

        others = [CDICT[m] for m in names(A) if haskey(CDICT,m)]
        if c in others
            ok = setdiff(COLOURS, others)
            isempty(ok) && return c  # nothing more we can do :(

            c = rand(ok)
            CNUM[] -= 1
        end
        return c
    end
end

CDICT = Dict(:_ => :light_black)
CNUM = Ref(1)
=#

function colour(A::AbstractArray, d)
    ranges_or_axes(A,d) === OneTo(1) && return :light_black
    # hasnames(A) && names(A,d) == :_ && return :light_black
    ranges_or_axes(A,d) isa OneTo && return :blue

    T = eltype(ranges_or_axes(A,d))

    T <: Integer && return :blue
    T <: Number && return :cyan
    T <: AbstractString && return :green
    T <: AbstractChar  && return :yellow
    T <: Symbol && return :magenta
    :red
end

#= TODO:

range printing is still too verbose, e.g.:
show(stdout, B(40µs .. 220µs).ranges[1])
AxisArrays avoids this... by keeping a range, uncollected!

printing fakearray is quite slow, as it's ::Any.
This takes about 0.35s, down from 0.8 but still:
ioc = IOContext(stdout, :displaysize => (30,30), :limit => true)
@time show(ioc, MIME("text/plain"), B)
Can I not create the whole thing? Can't need more than displaysize/2 rows/cols right?

=#

showtype(io::IO, ::RangeArray) =
    print(io, "RangeArray(...)")
showtype(io::IO, ::RangeArray{T,N,<:NamedDimsArray}) where {T,N} =
    print(io, "RangeArray(NamedDimsArray(...))")
showtype(io::IO, ::NamedDimsArray{L,T,N,<:RangeArray}) where {L,T,N} =
    print(io, "NamedDimsArray(RangeArray(...))")

#=

A = wrapdims(rand(20), r='a':'t')
C = wrapdims(rand(4,20), r='a':'d', col=10:10:200)
D = wrapdims(100 .* rand(4,20,3), r=[:a, :b, :c, :d], col=1:2:40, page=1:3)
E = wrapdims(OffsetArray(rand(3,6), 10,20), alpha=["one", "two", "three"], beta='A':'F')

permutedims(D, (3,1,2)) # error?
RangeArray(ones(Int,(3, 4, 20)))
view(ans, :,:,20) # error

F = wrapdims(rand(5), 'a':'z') # error!

=#

# These are to reduce the number of lines printed: (Base at arrayshow.jl:308)
# But doesn't seem to work for n-dims, so easier just to do it in print_matrix?

# print_array(io::IO, X::AbstractVecOrMat) = print_matrix(io, X)
# print_array(io::IO, X::AbstractArray) = show_nd(io, X, print_matrix, true)
# function Base.print_array(io::IO, A::RangeArray)
#     ioc = IOContext(io, :displaysize => displaysize(io) .- (ndims(A)+3, 0))
#     if ndims(A) == 0
#         isassigned(A) ? show(ioc, A[]) : print(io, Base.undef_ref_str)
#     elseif ndims(A) <= 2
#         Base.print_matrix(ioc, A)
#     else
#         Base.show_nd(ioc, A, Base.print_matrix, true)
#     end
# end


# This is called by each page of higher-dim arrays, that's good!

function Base.print_matrix(io::IO, A::RangeArray)
    fakearray = hcat(ShowWith.(no_offset(ranges(A,1)); color=colour(A,1)), no_offset(parent(A)))
    if ndims(A) == 2
        toprow = vcat(ShowWith(0, hide=true), ShowWith.(no_offset(ranges(A,2)); color=colour(A,2)))
        fakearray = vcat(permutedims(toprow), fakearray)
    end
    ioc = IOContext(io, :displaysize => displaysize(io) .- (ndims(A)+3, 0))
    Base.print_matrix(ioc, fakearray)
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
    # s = string("(", sprint(show, x.val; context=io, kw...),")")
    # s = sprint(show, x.val; context=io, kw...)
    s0 = sprint(show, x.val; context=io, kw...)
    s = x.val isa Symbol ? string(s0, ' ') : string(s0, ':')
    if x.hide
        printstyled(io, " "^length(s); x.nt...)
    else
        printstyled(io, s; x.nt...)
    end
end
Base.alignment(io::IO, x::ShowWith) =  alignment(io, x.val) .+ (1,0) # extra colon
Base.length(x::ShowWith) = length(string(x.val))
Base.print(io::IO, x::ShowWith) = printstyled(io, string(x.val); x.nt...)

# For higher-dim printing, I just want change the [:, :, 1] things, add name/key,
# but can't see a way to hook in. Just copy it?

using Base: tail, print_matrix, printstyled, alignment

Base.show_nd(io::IO, A::RangeArray, print_matrix::Function, label_slices::Bool) =
    _show_nd(io, A, print_matrix, label_slices)

Base.show_nd(io::IO, A::NamedDimsArray, print_matrix::Function, label_slices::Bool) =
    _show_nd(io, A, print_matrix, label_slices)

function _show_nd(io::IO, a::AbstractArray, print_matrix::Function, label_slices::Bool)
    c3 = colour(a, 3) # could be fancier

    limit::Bool = get(io, :limit, false)
    if isempty(a)
        return
    end
    tailinds = tail(tail(axes(a)))
    nd = ndims(a)-2
    for I in CartesianIndices(tailinds)
        idxs = I.I
        if limit
            for i = 1:nd
                ii = idxs[i]
                ind = tailinds[i]
                if length(ind) > 10
                    if ii == ind[firstindex(ind)+3] && all(d->idxs[d]==first(tailinds[d]),1:i-1)
                        for j=i+1:nd
                            szj = length(axes(a, j+2))
                            indj = tailinds[j]
                            if szj>10 && first(indj)+2 < idxs[j] <= last(indj)-3
                                @goto skip
                            end
                        end
                        #println(io, idxs)
                        print(io, "...\n\n")
                        @goto skip
                    end
                    if ind[firstindex(ind)+2] < ii <= ind[end-3]
                        @goto skip
                    end
                end
            end
        end
        if label_slices
            # Base has these 3 lines:
            # print(io, "[:, :, ")
            # for i = 1:(nd-1); print(io, "$(idxs[i]), "); end
            # println(io, idxs[end], "] =")
            printstyled(io, "[:, :", color=c3)
            for i = 1:nd
                if hasnames(a) && !hasranges(a)
                    name = names(a, i+2)
                    printstyled(io, ", $name = $(idxs[i])", color=c3)
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
        @label skip
    end
end

# Piracy to make NamedDimsArrays equally also pretty
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
        # printstyled(io, s2, color=colour(A,2))
        printstyled(io, s2, color=:magenta)
    end
    ioc = IOContext(io, :displaysize => displaysize(io) .- (2, 0))
    # Base.print_matrix(ioc, parent(A), ShowWith(s1, color=colour(A,1)))
    Base.print_matrix(ioc, parent(A), ShowWith(s1, color=:magenta))
end

#=
# A hack to avoid big messy function?

function Base.print_array(io::IO, A::NamedDimsArray{L,T,3}) where {L,T}
    s3 = string("[", names(A,3), " ⤋ ]")
    printstyled(io, s3, color=colour(A,3))
    Base.show_nd(io, A, Base.print_matrix, true)
end
function Base.print_array(io::IO, A::NamedDimsArray{L,T,4}) where {L,T}
    s3 = string("[", names(A,3),", ", names(A,4), " ⤋ ]")
    printstyled(io, s3, color=colour(A,3))
    Base.show_nd(io, A, Base.print_matrix, true)
end

=#
