
function Base.map(f, A::KeyedArray)
    data = map(f, parent(A))
    KeyedArray(data, map(copy, axiskeys(A)))#, copy(A.meta))
end
for fun in [:map, :map!], (T, S) in [ (:KeyedArray, :KeyedArray),
        (:KeyedArray, :AbstractArray), (:AbstractArray, :KeyedArray),
        (:KeyedArray, :NamedDimsArray), (:NamedDimsArray, :KeyedArray)] # for ambiguities

    @eval function Base.$fun(f, A::$T, B::$S, Cs::AbstractArray...)
        data = $fun(f, keyless(A), keyless(B), keyless.(Cs)...)
        new_keys = unify_keys(keys_or_axes(A), keys_or_axes(B), keys_or_axes.(Cs)...)
        KeyedArray(data, map(copy, new_keys)) # copy sometimes wasteful for map!, but OK.
    end
end

using Base: Generator

function Base.collect(x::Generator{<:KeyedArray})
    data = collect(Generator(x.f, x.iter.data))
    KeyedArray(data, map(copy, axiskeys(x.iter)))#, copy(A.meta))
end
function Base.collect(x::Generator{<:Iterators.Enumerate{<:KeyedArray}})
    data = collect(Generator(x.f, enumerate(x.iter.itr.data)))
    KeyedArray(data, map(copy, axiskeys(x.iter.itr)))
end
for Ts in [(:KeyedArray,), (:KeyedArray, :NamedDimsArray), (:NamedDimsArray, :KeyedArray)]
    @eval function Base.collect(x::Generator{<:Iterators.ProductIterator{<:Tuple{$(Ts...),Vararg{Any}}}})
        data = collect(Generator(x.f, Iterators.product(keyless.(x.iter.iterators)...)))
        all_keys = tuple_flatten(keys_or_axes.(x.iter.iterators)...)
        KeyedArray(data, map(copy, all_keys))
    end
end

tuple_flatten(x::Tuple, ys::Tuple...) = (x..., tuple_flatten(ys...)...)
tuple_flatten() = ()

function Base.mapreduce(f, op, A::KeyedArray; dims=:, kwargs...) # sum, prod, etc
    dims === Colon() && return mapreduce(f, op, parent(A); kwargs...)
    numerical_dims = NamedDims.dim(A, dims)
    data = mapreduce(f, op, parent(A); dims=numerical_dims, kwargs...)
    new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
    return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
end

using Statistics
for fun in [:mean, :std, :var] # These don't use mapreduce, but could perhaps be handled better?
    @eval function Statistics.$fun(A::KeyedArray; dims=:, kwargs...)
        dims === Colon() && return $fun(parent(A); kwargs...)
        numerical_dims = NamedDims.dim(A, dims)
        data = $fun(parent(A); dims=numerical_dims, kwargs...)
        new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
        return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
    end
end

# Handle function interface for `mean` only
if VERSION >= v"1.3"
    @eval function Statistics.mean(f, A::KeyedArray; dims=:, kwargs...)
        dims === Colon() && return mean(f, parent(A); kwargs...)
        numerical_dims = NamedDims.dim(A, dims)
        data = mean(f, parent(A); dims=numerical_dims, kwargs...)
        new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
        return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
    end
end

for fun in [:cov, :cor] # Returned the axes work are different for cov and cor
    @eval function Statistics.$fun(A::KeyedMatrix; dims=1, kwargs...)
        numerical_dim = NamedDims.dim(A, dims)
        data = $fun(parent(A); dims=numerical_dim, kwargs...)
        # Use same remaining axis for both dimensions of data
        rem_key = axiskeys(A, 3-numerical_dim)
        KeyedArray(data, (copy(rem_key), copy(rem_key)))
    end
end

function Base.dropdims(A::KeyedArray; dims)
    numerical_dims = NamedDims.dim(A, dims)
    data = dropdims(parent(A); dims=dims)
    new_keys = key_skip(axiskeys(A), numerical_dims...)
    KeyedArray(data, new_keys)#, A.meta)
end

key_skip(tup::Tuple, d, dims...) = key_skip(
    ntuple(n -> n<d ? tup[n] : tup[n+1], length(tup)-1),
    map(n -> n<d ? n : n-1, dims)...)
key_skip(tup::Tuple) = tup

function Base.permutedims(A::KeyedArray, perm)
    numerical_perm = hasnames(A) ? NamedDims.dim(dimnames(A), perm) : perm
    data = permutedims(parent(A), numerical_perm)
    new_keys = ntuple(d -> copy(axiskeys(A, perm[d])), ndims(A))
    KeyedArray(data, new_keys)#, copy(A.meta))
end

@static if VERSION > v"1.9-DEV"
    function Base.eachslice(A::KeyedArray; dims)
        dims_ix = AxisKeys.dim(A, dims) |> Tuple
        data = @invoke eachslice(A::AbstractArray; dims=dims_ix)
        return KeyedArray(NamedDimsArray(data, map(d -> dimnames(A, d), dims_ix)), map(d -> axiskeys(A, d), dims_ix))
    end
elseif VERSION >= v"1.1"
    # This copies the implementation from Base, except with numerical_dims:
    @inline function Base.eachslice(A::KeyedArray; dims)
        numerical_dims = NamedDims.dim(A, dims)
        length(numerical_dims) == 1 || throw(ArgumentError("only single dimensions are supported"))
        dim = first(numerical_dims)
        dim <= ndims(A) || throw(DimensionMismatch("A doesn't have $dim dimensions"))
        inds_before = ntuple(d->(:), dim-1)
        inds_after = ntuple(d->(:), ndims(A)-dim)
        return (view(A, inds_before..., i, inds_after...) for i in axes(A, dim))
    end
end

@static if VERSION > v"1.9-DEV"
    # TODO: this will ERROR if given dims, instead of falling back to Base
    # TODO: ideally it would dispatch on the element type, for e.g. a generator of KeyedArrays
    function Base.stack(A::KeyedArray; dims::Colon=:)
        data = @invoke stack(A::AbstractArray; dims)
        if !allequal(named_axiskeys(a) for a in A)
            throw(DimensionMismatch("stack expects uniform axiskeys for all arrays"))
        end
        akeys = (; named_axiskeys(first(A))..., named_axiskeys(A)...)
        KeyedArray(data; akeys...)
    end
end

function Base.mapslices(f, A::KeyedArray; dims)
    numerical_dims = NamedDims.dim(A, dims)
    data = mapslices(f, parent(A); dims=numerical_dims)
    new_keys = ntuple(ndims(A)) do d
        d in numerical_dims ? axes(data,d) : copy(axiskeys(A, d))
    end
    KeyedArray(data, new_keys)#, copy(A.meta))
end

Base.selectdim(A::KeyedArray, s::Symbol, i) = selectdim(A, NamedDims.dim(A, s), i)

for (T, S) in [(:KeyedVecOrMat, :KeyedVecOrMat), # KeyedArray gives ambiguities
    (:KeyedVecOrMat, :AbstractVecOrMat), (:AbstractVecOrMat, :KeyedVecOrMat),
    (:NdaKaVoM, :NdaKaVoM),
    (:NdaKaVoM, :KeyedVecOrMat), (:KeyedVecOrMat, :NdaKaVoM),
    (:NdaKaVoM, :AbstractVecOrMat), (:AbstractVecOrMat, :NdaKaVoM),
    ]

    @eval function Base.vcat(A::$T, B::$S, Cs::AbstractVecOrMat...)
        data = vcat(keyless(A), keyless(B), keyless.(Cs)...)
        new_1 = key_vcat(keys_or_axes(A,1), keys_or_axes(B,1), keys_or_axes.(Cs,1)...)
        new_keys = ndims(A) == 1 ? (new_1,) :
            (new_1, unify_one(keys_or_axes(A,2), keys_or_axes(B,2), keys_or_axes.(Cs,2)...))
        KeyedArray(data, map(copy, new_keys))
    end

    @eval function Base.hcat(A::$T, B::$S, Cs::AbstractVecOrMat...)
        data = hcat(keyless(A), keyless(B), keyless.(Cs)...)
        new_1 = unify_one(keys_or_axes(A,1), keys_or_axes(B,1), keys_or_axes.(Cs,1)...)
        new_2 = ndims(A) == 1 ? axes(data,2) :
            key_vcat(keys_or_axes(A,2), keys_or_axes(B,2), keys_or_axes.(Cs,2)...)
        KeyedArray(data, map(copy, (new_1, new_2)))
    end

end
for (T, S) in [ (:KeyedArray, :KeyedArray),
        (:KeyedArray, :AbstractArray), (:AbstractArray, :KeyedArray),
        (:KeyedArray, :NamedDimsArray), (:NamedDimsArray, :KeyedArray),
        (:NdaKa, :NdaKa),
        (:NdaKa, :KeyedArray), (:KeyedArray, :NdaKa),
        (:NdaKa, :AbstractArray), (:AbstractArray, :NdaKa),
        ]

    @eval function Base.cat(A::$T, B::$S, Cs::AbstractArray...; dims)
        numerical_dims, data = if any(hasnames.((A, B, Cs...)))
            old_names = NamedDims.unify_names_longest(dimnames(A), dimnames(B), dimnames.(Cs)...)
            new_names = NamedDims.expand_dimnames(old_names, dims)
            α = NamedDims.dim(new_names, dims)
            β = cat(keyless(A), keyless(B), keyless.(Cs)...; dims=dims)
            α, β
        else
            α = val_strip(dims)
            β = cat(keyless(A), keyless(B), keyless.(Cs)...; dims=numerical_dims)
            α, β
        end
        new_keys = ntuple(ndims(data)) do d
            if d in numerical_dims
                key_vcat(keys_or_axes(A,d), keys_or_axes(B,d), keys_or_axes.(Cs,d)...)
            else
                unify_one(keys_or_axes(A,d), keys_or_axes(B,d), keys_or_axes.(Cs,d)...)
            end
        end
        KeyedArray(data, map(copy, new_keys)) # , copy(A.meta))
    end

end
# single argument
Base.vcat(A::KeyedArray) = A
function Base.hcat(A::KeyedArray)
    data = hcat(keyless(A))
    akeys = map(copy, (keys_or_axes(A, 1), keys_or_axes(A, 2)))
    KeyedArray(data, akeys)
end
function Base.cat(A::KeyedArray; dims)
    new_names = NamedDims.expand_dimnames(dimnames(A), dims)
    numerical_dims = NamedDims.dim(new_names, dims)
    data = cat(keyless(A); dims=dims)
    new_keys = ntuple(d -> keys_or_axes(A, d), ndims(data))
    KeyedArray(data, map(copy, new_keys)) # , copy(A.meta))
end

val_strip(dims::Val{d}) where {d} = d
val_strip(dims) = dims
key_vcat(a::AbstractVector, b::AbstractVector) = vcat(a,b)
key_vcat(a::Base.OneTo, b::Base.OneTo) = Base.OneTo(a.stop + b.stop)
key_vcat(a,b,cs...) = key_vcat(key_vcat(a,b),cs...)

for T in [ :(AbstractVector{<:KeyedVecOrMat}),
        :(AbstractVector{<:NdaKaVoM}),
        :(KeyedVector{<:AbstractVecOrMat}),
        :(KeyedVector{<:KeyedVecOrMat}),
        :(NdaKaV{<:Any, <:AbstractVecOrMat}),
        :(NdaKaV{<:Any, <:KeyedVecOrMat}),
        ]
    @eval function Base.reduce(::typeof(hcat), As::$T)
        data = reduce(hcat, map(keyless, keyless(As)))
        # Compromise between checking all elements & trusting the first:
        new_1 = unify_one(keys_or_axes(first(As),1), keys_or_axes(last(As),1))
        new_2 = if eltype(As) <: AbstractVector  # then elements cannot have keyvectors
            copy(keys_or_axes(As,1))
        elseif !(keys_or_axes(first(As),2) isa Base.OneTo)
            reduce(vcat, map(last∘keys_or_axes, As))
        else
            axes(data,2)
        end
        KeyedArray(data, (new_1, new_2))
    end
end
for T in [ :(AbstractVector{<:KeyedVecOrMat}),
        :(AbstractVector{<:NdaKaVoM}),
        ]
    @eval function Base.reduce(::typeof(vcat), As::$T)
        data = reduce(vcat, map(keyless, keyless(As)))
        # Unlike reduce_hcat, it's very unlikely that the outer array's keys matter, so ignore them:
        new_1 = reduce(vcat, map(first∘keys_or_axes, As))
        new_keys = if ndims(eltype(As)) == 1
            (new_1,)
        else
            new_2 = unify_one(keys_or_axes(first(As),2), keys_or_axes(last(As),2))
            (new_1, new_2)
        end
        KeyedArray(data, new_keys)
    end
end

function Base.reverse(A::KeyedArray; dims = ntuple(identity, ndims(A)))
    dims′ = NamedDims.dim(A, dims)
    data = reverse(parent(A); dims=dims′)
    new_keys = ntuple(d -> d in dims′ ? reverse(axiskeys(A,d)) : copy(axiskeys(A,d)), ndims(A))
    KeyedArray(data, new_keys) # , copy(A.meta))
end

function Base.sort(A::KeyedArray; dims, kw...)
    dims′ = NamedDims.dim(A, dims)
    data = sort(parent(A); dims=dims′, kw...)
    # sorts each (say) col independently, thus keys along them loses meaning.
    new_keys = ntuple(d -> d==dims′ ? OneTo(size(A,d)) : axiskeys(A,d), ndims(A))
    KeyedArray(data, map(copy, new_keys)) # , copy(A.meta))
end
function Base.sort(A::KeyedVector; kw...)
    perm = sortperm(parent(A); kw...)
    KeyedArray(parent(A)[perm], (axiskeys(A,1)[perm],)) # , copy(A.meta))
end

function Base.sort!(A::KeyedVector; kw...)
    perm = sortperm(parent(A); kw...)
    permute!(axiskeys(A,1), perm) # error if keys cannot be sorted, could treat like push!
    permute!(parent(A), perm)
    A
end

sort_doc = """
    sortslices(A; dims)
    sortkeys(A; dims=1:ndims(A))

`Base.sortslices` sorts the corresponding keys too, along one dimension.
Calls its own implementation, roughly `p = sortperm(eachslice(A))`,
with default keyword `by=vec` to make this work on slices of any shape.

`sortkeys(A)` instead sorts everything by the keys.
Works along any number of dimensions, by detault all of them.
"""

@doc sort_doc
function Base.sortslices(A::KeyedArray; dims, by=vec, kw...)
    dim′ = NamedDims.dim(A, dims)
    perms = ntuple(ndims(A)) do d
        d in dim′ || return Colon()
        sortperm(collect(eachslice(parent(A), dims=dim′)); by=by, kw...)
    end
    new_keys = map(getindex, axiskeys(A), perms)
    KeyedArray(keyless(A)[perms...], new_keys) # , copy(A.meta))
end

if VERSION < v"1.1" # defn copied Julia 1.4 Base abstractarraymath.jl:452
    @inline function eachslice(A::AbstractArray; dims)
        length(dims) == 1 || throw(ArgumentError("only single dimensions are supported"))
        dim = first(dims)
        dim <= ndims(A) || throw(DimensionMismatch("A doesn't have $dim dimensions"))
        inds_before = ntuple(d->(:), dim-1)
        inds_after = ntuple(d->(:), ndims(A)-dim)
        return (view(A, inds_before..., i, inds_after...) for i in axes(A, dim))
    end
end

@doc sort_doc
function sortkeys(A::Union{KeyedArray, NdaKa}; dims=1:ndims(A), kw...)
    dims′ = NamedDims.dim(A, dims)
    perms = ntuple(ndims(A)) do d
        d in dims′ || return Colon()
        axiskeys(A,d) isa AbstractUnitRange && return Colon() # avoids OneTo(n) -> 1:n
        sortperm(axiskeys(A,d); kw...)
    end
    new_keys = map(getindex, axiskeys(A), perms)
    KeyedArray(keyless(A)[perms...], new_keys) # , copy(A.meta))
end

Base.filter(f, A::KeyedVector) = getindex(A, map(f, parent(A)))
Base.filter(f, A::KeyedArray) = filter(f, parent(A))

using LinearAlgebra

for (mod, fun, lazy) in [(Base, :permutedims, false),
        (LinearAlgebra, :transpose, true), (LinearAlgebra, :adjoint, true)]
    @eval function $mod.$fun(A::KeyedArray)
        data = $mod.$fun(parent(A))
        new_keys = ndims(A)==1 ? (Base.OneTo(1), axiskeys(A,1)) :
            ndims(data)==1 ? (axiskeys(A,2),) :
            reverse(axiskeys(A))
        KeyedArray(data, $(lazy ? :new_keys : :(map(copy, new_keys))))#, $(lazy ? :(A.meta) : :(copy(A.meta))))
    end
end

Base.reshape(A::KeyedArray, dims::Tuple{Vararg{Int}}) = reshape(parent(A), dims...) # for ambiguities
Base.reshape(A::KeyedArray, dims::Tuple{Vararg{Union{Colon, Int}}}) = reshape(parent(A), dims...)

for fun in [:copy, :deepcopy, :similar, :zero, :one]
    @eval Base.$fun(A::KeyedArray) = KeyedArray($fun(parent(A)), map(copy, axiskeys(A)))
    @eval Base.$fun(A::NdaKa) = NamedDimsArray(KeyedArray(
        $fun(parent(parent(A))),
        map(copy, axiskeys(A))), dimnames(A))
end
Base.similar(A::KeyedArray, T::Type) = KeyedArray(similar(parent(A), T), map(copy, axiskeys(A)))
Base.similar(A::NdaKa, T::Type) = NamedDimsArray(KeyedArray(
    similar(parent(parent(A)), T), map(copy, axiskeys(A))), dimnames(A))
Base.similar(A::KeyedArray, T::Type, dims::Int...) = similar(parent(A), T, dims...)
Base.similar(A::KeyedArray, dims::Int...) = similar(parent(A), dims...)

for fun in [:(==), :isequal, :isapprox]
    for (T, S) in [ (:KeyedArray, :KeyedArray), (:KeyedArray, :NdaKa), (:NdaKa, :KeyedArray) ]
        @eval function Base.$fun(A::$T, B::$S; kw...)
            # Ideally you would pass isapprox(, atol) into unifiable_keys?
            return $fun(keyless(A), keyless(B); kw...) && unifiable_keys(axiskeys(A), axiskeys(B))
        end
    end
end

Rlist = [:KeyedMatrix, :KeyedVector,
    :(NdaKa{L,T,2} where {L,T}), :(NdaKa{L,T,1} where {L,T}),
    :(KeyedVector{T} where {T<:Number}), :(NdaKa{L,T,1} where {L,T<:Number}), # ambiguities on 1.5
    ]

Olist = [ :AbstractMatrix, :AbstractVector, :Number,
    :(Adjoint{<:Any,<:AbstractMatrix}), :(Adjoint{<:Any,<:AbstractVector}),
    :(Transpose{<:Any,<:AbstractMatrix}), :(Transpose{<:Any,<:AbstractVector}),
    :(NamedDimsArray{L,T,1} where {L,T}), :(NamedDimsArray{L,T,2} where {L,T}),
    :(Adjoint{<:Number,<:AbstractVector}), # 1.5 problem...
    :(Diagonal), :(Union{LowerTriangular, UpperTriangular}),
    ]
for (Ts, Ss) in [(Rlist, Rlist), (Rlist, Olist), (Olist, Rlist)]
    for T in Ts, S in Ss # some combinations are errors, later, that's ok

        @eval Base.:*(x::$T, y::$S) = matmul(x,y)
        @eval Base.:\(x::$T, y::$S) = ldiv(x,y)
        @eval Base.:/(x::$T, y::$S) = rdiv(x,y)

    end
end

# Specific methods to resolve ambiguities in 1.6
for A in (:(Adjoint{<:Any, <:AbstractMatrix{T}}), :(Transpose{<:Any, <:AbstractMatrix{T}}))
    @eval Base.:*(x::$A{T}, y::KeyedVector{S}) where {T, S<:Number} = matmul(x, y)
    @eval Base.:*(x::$A{T}, y::NdaKaV{L, S}) where {T, L, S<:Number} = matmul(x, y)
end

for (fun, op) in [(:matmul, :*), (:ldiv, :\), (:rdiv, :/)]
    @eval $fun(x::AbstractVecOrMat, y::Number) = KeyedArray($op(keyless(x), y), axiskeys(x))
    @eval $fun(x::Number, y::AbstractVecOrMat) = KeyedArray($op(x, keyless(y)), axiskeys(y))
    @eval $fun(x::AbstractVector, y::AbstractVector) = $op(keyless(x), keyless(y))
end

function matmul(x::AbstractMatrix, y::AbstractVecOrMat)
    data = keyless(x) * keyless(y)
    unify_one(keys_or_axes(x,2), keys_or_axes(y,1)) # just a check, discard these
    if data isa AbstractVecOrMat
        new_keys = (keys_or_axes(x,1), Base.tail(keys_or_axes(y))...)
        KeyedArray(data, map(copy, new_keys))
    else
        data # case V' * V
    end
end
function matmul(x::AbstractVector, y::AbstractMatrix) # used for v * v'
    data = keyless(x) * keyless(y)
    new_keys = (keys_or_axes(x,1), keys_or_axes(y,2))
    KeyedArray(data, map(copy, new_keys))
end

# case of two vectors gives a scalar, caught above.
function ldiv(x::AbstractVecOrMat, y::AbstractVecOrMat)
    data = keyless(x) \ keyless(y)
    unify_one(keys_or_axes(x,1), keys_or_axes(y,1))
    new_keys = (Base.tail(keys_or_axes(x))..., Base.tail(keys_or_axes(y))...)
    KeyedArray(data, map(copy, new_keys))
end
function rdiv(x::AbstractVecOrMat, y::AbstractVecOrMat)
    data = keyless(x) / keyless(y)
    # unify_one(keys_or_axes(x,2), keys_or_axes(y,2)) # not right!
    # new_keys = (tup_head(keys_or_axes(x))..., tup_head(keys_or_axes(y))...)
    # KeyedArray(data, new_keys)
    @warn "/ doesn't preserve keys yet, sorry" maxlog=1
    data
end

tup_head(t::Tuple) = reverse(Base.tail(reverse(t)))

for fun in [:inv, :pinv,
    :det, :logdet, :logabsdet,
    :eigen, :eigvecs, :eigvals, :svd,
    :diag
    ]
    @eval LinearAlgebra.$fun(A::KeyedMatrix) = $fun(parent(A))
end

LinearAlgebra.cholesky(A::Hermitian{T, <:KeyedArray{T}}; kwargs...) where {T} =
    cholesky(parent(A); kwargs...)
LinearAlgebra.cholesky(A::KeyedMatrix; kwargs...) =
    cholesky(keyless_unname(A); kwargs...)

function Base.deleteat!(v::KeyedVector, inds)
    deleteat!(axiskeys(v, 1), inds)
    deleteat!(v.data, inds)
    return v
end

function Base.filter!(f, a::KeyedVector)
    j = firstindex(a)
    @inbounds for i in eachindex(a)
        a[j] = a[i]
        axiskeys(a, 1)[j] = axiskeys(a, 1)[i]
        j = ifelse(f(a[i]), j + 1, j)
    end
    deleteat!(a, j:lastindex(a))
    return a
end

function Base.empty!(v::KeyedVector)
    empty!(axiskeys(v, 1))
    empty!(v.data)
    return v
end
