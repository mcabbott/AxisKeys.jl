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

    # R_inds comprises the indices for each of the keys.
    
    R_inds = map(eachindex, R)
    # indices is a tuple, the dth element of which is an index for the dth column of R.
    # By using these indices, and mapping over the columns of R, the compiler seems to
    # successfully infer the types in G, because it knows the element types of each column
    # of R, so is presumably able to unroll the call to map.
    # The previous implementation called `Iterators.product` on `R` and pulled out
    # the dth element of `indices`, whose type it could not infer.
    G = map(
        (r, d) -> vec([r[indices[d]] for indices in Iterators.product(R_inds...)]),
        R, ntuple(identity, length(R)),
    )
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
    wrapdims(table, value, names...; default=undef, sort=false, force=false)

Construct `KeyedArray(NamedDimsArray(A,names),keys)` from a `table` matching
the [Tables.jl](https://github.com/JuliaData/Tables.jl) API.
(It must support both `Tables.columns` and `Tables.rows`.)

The contents of the array is taken from the column `value::Symbol` of the table.
Each symbol in `names` specifies a column whose unique entries
become the keys along a dimenension of the array.

If there is no row in the table matching a possible set of keys,
then this element of the array is undefined, unless you provide the `default` keyword.
If several rows share the same set of keys, then by default an `ArgumentError` is thrown.
Keyword `force=true` will instead cause these non-unique entries to be overwritten.

See also [`populate!`](@ref) to fill an existing array in the same manner.

Setting `AxisKeys.nameouter() = false` will reverse the order of wrappers produced.

# Examples
```jldoctest
julia> using DataFrames, AxisKeys

julia> df = DataFrame("a" => 1:3, "b" => 10:12.0, "c" => ["cat", "dog", "cat"])
3×3 DataFrame
 Row │ a      b        c      
     │ Int64  Float64  String 
─────┼────────────────────────
   1 │     1     10.0  cat
   2 │     2     11.0  dog
   3 │     3     12.0  cat

julia> wrapdims(df, :a, :b, :c; default=missing)
2-dimensional KeyedArray(NamedDimsArray(...)) with keys:
↓   b ∈ 3-element Vector{Float64}
→   c ∈ 2-element Vector{String}
And data, 3×2 Matrix{Union{Missing, Int64}}:
         ("cat")    ("dog")
 (10.0)   1           missing
 (11.0)    missing   2
 (12.0)   3           missing

julia> wrapdims(df, :a, :b)
1-dimensional NamedDimsArray(KeyedArray(...)) with keys:
↓   b ∈ 3-element Vector{Float64}
And data, 3-element Vector{Union{Missing, Int64}}:
 (10.0)  1
 (11.0)  2
 (12.0)  3

julia> wrapdims(df, :a, :c)
ERROR: ArgumentError: Key ("cat",) is not unique

julia> wrapdims(df, :a, :c, force=true)
1-dimensional NamedDimsArray(KeyedArray(...)) with keys:
↓   c ∈ 2-element Vector{String}
And data, 2-element Vector{Int64}:
 ("cat")  3
 ("dog")  2
```
"""
function wrapdims(table, value::Symbol, names::Symbol...; kw...)
    if nameouter() == false
        _wrap_table(KeyedArray, identity, table, value, names...; kw...)
    else
        _wrap_table(NamedDimsArray, identity, table, value, names...; kw...)
    end
end

"""
    wrapdims(df, UniqueVector, :val, :x, :y)

Converts at Tables.jl table to a `KeyedArray` + `NamedDimsArray` pair,
using column `:val` for values, and columns `:x, :y` for names & keys.
Optional 2nd argument applies this type to all the key-vectors.
"""
function wrapdims(table, KT::Type, value::Symbol, names::Symbol...; kw...)
    if nameouter() == false
        _wrap_table(KeyedArray, KT, table, value, names...; kw...)
    else
        _wrap_table(NamedDimsArray, KT, table, value, names...; kw...)
    end
end

function _wrap_table(AT::Type, KT, table, value::Symbol, names::Symbol...; default=undef, sort::Bool=false, kwargs...)
    # get columns of the input table source
    cols = Tables.columns(table)

    # Extract key columns
    pairs = map(names) do k
        col = unique(Tables.getcolumn(cols, k))
        sort && Base.sort!(col)
        return k => KT(col)
    end

    # Extract data/value column
    vals = Tables.getcolumn(cols, value)

    # Initialize the KeyedArray
    sz = length.(last.(pairs))
    if default === undef
        data = similar(vals, sz)
    else
        data = similar(vals, Union{eltype(vals), typeof(default)}, sz)
        fill!(data, default)
    end
    A = AT(data; pairs...)

    populate!(A, table, value; kwargs...)
    return A
end
