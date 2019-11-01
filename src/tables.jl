#=
This is a very crude first stab at the Tables.jl interface
https://github.com/JuliaData/Tables.jl
=#

using Tables

Tables.istable(::Type{<:RangeArray}) = true

Tables.rowaccess(::Type{<:RangeArray}) = true

function Tables.rows(A::RangeArray)
    L = hasnames(A) ? (names(A)..., :value) :  # should gensym() if :value in names(A)
        (ntuple(d -> Symbol(:dim_,d), ndims(A))..., :value)
    R = ranges(A)
    nt(inds) = NamedTuple{L}((map(getindex, R, inds)..., A[inds...]))
    # (nt(inds) for inds in Iterators.product(axes(A)...)) # should flatten?
    (nt(inds) for inds in Vectorator(Iterators.product(axes(A)...)))
end

#=
rr = wrapdims(rand(2,3), 11:12, 21:23)
nn = wrapdims(rand(2,3), a=11:12, b=21:23)

Tables.rows(rr) |> collect |> vec
Tables.rows(nn) |> collect |> vec

Tables.Schema(nn) # define a struct? Now below...

# No error if Tables.rows's generator has size,
# it uses Vectorator mostly to give Tables.Schema something to find.
=#

Tables.columnaccess(::Type{<:RangeArray{T,N,AT}}) where {T,N,AT} =
    IndexStyle(AT) === IndexLinear()

function Tables.columns(A::RangeArray)
    L = hasnames(A) ? (names(A)..., :value) :
        (ntuple(d -> Symbol(:dim_,d), ndims(A))..., :value)
    R = ranges(A)
    G = ntuple(ndims(A)) do d
        vec([rs[d] for rs in Iterators.product(R...)])
        # _vec(rs[d] for rs in Iterators.product(R...))
    end
    C = (G..., vec(parent(A)))
    NamedTuple{L}(C)
end

function Tables.Schema(nt::NamedTuple) # 🏴‍☠️
    L = keys(nt)
    T = map(v -> typeof(first(v)), values(nt))
    Tables.Schema(L,T)
end

#=
Ah, iterators aren't allowed for columns, must be indexable:
https://github.com/JuliaData/Tables.jl/issues/101
They could be something like this, but seems overkill?
https://github.com/MichielStock/Kronecker.jl
https://github.com/JuliaArrays/LazyArrays.jl#kronecker-products

Tables.columns(nn)
map(collect, Tables.columns(nn))

using DataFrames

DataFrame(rand(2,3))
DataFrame(nn) # doesn't see Tables

dd1 = DataFrame(Tables.rows(nn))
dd2 = DataFrame(Tables.columns(nn))
=#


"""
    Vectorator(iter)

Wrapper for iterators which ensures they do not have an n-dimensional size.
Tries to ensure that `collect(Vectorator(iter)) == vec(collect(iter))`.
"""
struct Vectorator{T}
    iter::T
end

_vec(iter) = (x for x in Vectorator(iter))

Base.iterate(x::Vectorator, s...) = iterate(x.iter, s...)

Base.length(x::Vectorator) = length(x.iter)

Base.IteratorSize(::Type{Vectorator{T}}) where {T} =
    Base.IteratorSize(T) isa Base.HasShape ? Base.HasLength() : IteratorSize(T)

Base.IteratorEltype(::Type{Vectorator{T}}) where {T} = Base.IteratorEltype(T)

Base.eltype(::Type{Vectorator{T}}) where {T} = eltype(T)

function Tables.Schema(rows::Base.Generator{<:Vectorator})
    row = first(rows)
    Tables.Schema(keys(row), map(typeof, values(row)))
end

# struct OneKron{T, AT} <: AbstractVector{T}
#     data::AT
#     inner::Int
#     outer::Int
# end


# Tables.materializer(A::RangeArray) = wrapdims

# function wrapdims(tab)
#     sch = Tables.Schema(tab)
#     for r in Tables.rows(tab)

#     end
# end
