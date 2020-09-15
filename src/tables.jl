#=
This is a very crude first stab at the Tables.jl interface
https://github.com/JuliaData/Tables.jl
=#

using Tables

Tables.istable(::Type{<:KeyedArray}) = true

Tables.rowaccess(::Type{<:KeyedArray}) = true

function Tables.rows(A::Union{KeyedArray, NdaKa})
    L = hasnames(A) ? (dimnames(A)..., :value) :  # should gensym() if :value in dimnames(A)
        (ntuple(d -> Symbol(:dim_,d), ndims(A))..., :value)
    R = keys_or_axes(A)
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

Tables.columnaccess(::Type{<:KeyedArray{T,N,AT}}) where {T,N,AT} =
    IndexStyle(AT) === IndexLinear()

function Tables.columns(A::Union{KeyedArray, NdaKa})
    L = hasnames(A) ? (dimnames(A)..., :value) :
        (ntuple(d -> Symbol(:dim_,d), ndims(A))..., :value)
    R = keys_or_axes(A)
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


# Tables.materializer(A::KeyedArray) = wrapdims

# function wrapdims(tab)
#     sch = Tables.Schema(tab)
#     for r in Tables.rows(tab)

#     end
# end

"""
    populate!(A, table, value)

Populate A with the contents of the `value` column in a provided table.
The provided table contain columns corresponding to the keys in A and support row iteration.
"""
function populate!(A, table, value::Symbol)
    cols = [value, dimnames(A)...]
    for r in Tables.rows(table)
        setkey!(A, (Tables.getcolumn(r, c) for c in cols)...)
    end
    return A
end

"""
    KeyedArray(table, value, keys...; default=undef)
    NamedDimsArray(table, value, keys...; default=undef)

Construct a KeyedArray/NamedDimsArray from a `table` supporting column and row.
`keys` columns are extracted as is, without sorting, and are assumed to uniquely identify
each `value`. The `default` value is used in cases where no value is identified for a given
keypair.
"""
function KeyedArray(table, value::Symbol, keys::Symbol...; kwargs...)
   return _construct_from_table(KeyedArray, table, value, keys...; kwargs...)
end

function NamedDimsArray(table, value::Symbol, keys::Symbol...; kwargs...)
   return _construct_from_table(NamedDimsArray, table, value, keys...; kwargs...)
end


# Internal function for constructing the KeyedArray or NamedDimsArray.
# This code doesn't care which type we produce so we just pass that along.
function _construct_from_table(
    T::Type, table, value::Symbol, keys::Symbol...;
    default=undef, issorted=false
)
    # get columns of the input table source
    cols = Tables.columns(table)

    # Extract key columns
    kw = Tuple(k => unique(Tables.getcolumn(cols, k)) for k in keys)

    # Extract data/value column
    vals = Tables.getcolumn(cols, value)

    # Initialize the KeyedArray
    sz = length.(last.(kw))

    A = if default === undef
        data = similar(vals, sz)
    else
        data = similar(vals, Union{eltype(vals), typeof(default)}, sz)
        fill!(data, default)
    end

    A = T(data; kw...)
    populate!(A, table, value)
    return A
end
