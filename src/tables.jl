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
    AxisKeys.populate!(A, table, value; force=false)

Populate `A` with the contents of the `value` column in a provided `table`, matching the
[Tables.jl](https://github.com/JuliaData/Tables.jl) API. The `table` must contain columns
corresponding to the keys in `A` and implements `Tables.rows`. If the keys in `A` do not
uniquely identify rows in the `table` then an `ArgumentError` is throw. If `force` is true
then the duplicate (non-unique) entries will be overwritten.
"""
function populate!(A, table, value::Symbol; force=false)
    # Use a BitArray mask to detect duplicates and error instead of overwriting.
    mask = force ? falses() : falses(size(A))

    for r in Tables.rows(table)
        vals = Tuple(Tables.getcolumn(r, c) for c in dimnames(A))
        inds = map(findindex, vals, axiskeys(A))

        # Handle duplicate error checking if applicable
        if !force
            # Error if mask already set.
            mask[inds...] && throw(ArgumentError("Key $vals is not unique"))
            # Set mask, marking that we've set this index
            setindex!(mask, true, inds...)
        end

        # Insert our value into the data array
        setindex!(A, Tables.getcolumn(r, value), inds...)
    end

    return A
end

"""
    wrapdims(table, value, keys...; default=undef, sort=false, force=false) -> KeyedArray
    wrapdims(T, table, value, keys...; default=undef, sort=false, force=false) -> T

Construct a `KeyedArray`/`NamedDimsArray` (specified by type `T`) from a `table` matching
the [Tables.jl](https://github.com/JuliaData/Tables.jl) API. The `table` should support both
`Tables.columns` and `Tables.rows`. The `default` value is used in cases where no
value is identified for a given keypair. If the `keys` columns do not uniquely identify
rows in the table then an `ArgumentError` is throw. If `force` is true then the duplicate
(non-unique) entries will be overwritten.
"""
function wrapdims(table, value::Symbol, keys::Symbol...; kwargs...)
    wrapdims(KeyedArray, table, value, keys...; kwargs...)
end

function wrapdims(T::Type, table, value::Symbol, keys::Symbol...; default=undef, sort::Bool=false, kwargs...)
    # get columns of the input table source
    cols = Tables.columns(table)

    # Extract key columns
    pairs = map(keys) do k
        col = unique(Tables.getcolumn(cols, k))
        sort && Base.sort!(col)
        return k => col
    end

    # Extract data/value column
    vals = Tables.getcolumn(cols, value)

    # Initialize the KeyedArray
    sz = length.(last.(pairs))

    A = if default === undef
        data = similar(vals, sz)
    else
        data = similar(vals, Union{eltype(vals), typeof(default)}, sz)
        fill!(data, default)
    end

    A = T(data; pairs...)
    populate!(A, table, value; kwargs...)
    return A
end
