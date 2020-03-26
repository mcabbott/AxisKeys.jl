
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

function Base.mapreduce(f, op, A::KeyedArray; dims=:) # sum, prod, etc
    dims === Colon() && return mapreduce(f, op, parent(A))
    numerical_dims = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
    data = mapreduce(f, op, parent(A); dims=numerical_dims)
    new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
    return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
end

using Statistics
for fun in [:mean, :std, :var] # These don't use mapreduce, but could perhaps be handled better?
    @eval function Statistics.$fun(A::KeyedArray; dims=:)
        dims === Colon() && return $fun(parent(A))
        numerical_dims = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
        data = $fun(parent(A); dims=numerical_dims)
        new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
        return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
    end
    VERSION >= v"1.3" &&
    @eval function Statistics.$fun(f, A::KeyedArray; dims=:)
        dims === Colon() && return $fun(f, parent(A))
        numerical_dims = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
        data = $fun(f, parent(A); dims=numerical_dims)
        new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
        return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
    end
end

function Base.dropdims(A::KeyedArray; dims)
    numerical_dims = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
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

function Base.mapslices(f, A::KeyedArray; dims)
    numerical_dims = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
    data = mapslices(f, parent(A); dims=dims)
    new_keys = ntuple(ndims(A)) do d
        d in dims ? axes(data,d) : copy(axiskeys(A, d))
    end
    KeyedArray(data, new_keys)#, copy(A.meta))
end

for (T, S) in [(:KeyedVecOrMat, :KeyedVecOrMat), # KeyedArray gives ambiguities
    (:KeyedVecOrMat, :AbstractVecOrMat), (:AbstractVecOrMat, :KeyedVecOrMat),
    (:NdaKaVoM, :NdaKaVoM), # These are needed because hcat(NamedDimsArray...) relies on similar()
    (:NdaKaVoM, :KeyedVecOrMat), (:KeyedVecOrMat, :NdaKaVoM),
    (:NdaKaVoM, :AbstractVecOrMat), (:AbstractVecOrMat, :NdaKaVoM) ]

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
        (:NdaKa, :AbstractArray), (:AbstractArray, :NdaKa) ]

    @eval function Base.cat(A::$T, B::$S, Cs::AbstractArray...; dims)
        # numerical_dims = hasnames(A) || hasnames(B) ? ... todo!
        data = cat(keyless(A), keyless(B), keyless.(Cs)...; dims=dims)
        new_keys = ntuple(ndims(data)) do d
            if d in dims
                key_vcat(keys_or_axes(A,d), keys_or_axes(B,d), keys_or_axes.(Cs,d)...)
            else
                unify_one(keys_or_axes(A,d), keys_or_axes(B,d), keys_or_axes.(Cs,d)...)
            end
        end
        KeyedArray(data, map(copy, new_keys))
    end

end
key_vcat(a::AbstractVector, b::AbstractVector) = vcat(a,b)
key_vcat(a::Base.OneTo, b::Base.OneTo) = Base.OneTo(a.stop + b.stop)
key_vcat(a,b,cs...) = key_vcat(key_vcat(a,b),cs...)

function Base.sort(A::KeyedArray; dims, kw...)
    dims′ = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
    data = sort(parent(A); dims=dims′, kw...)
    # sorts each (say) col independently, thus keys along them loses meaning.
    new_keys = ntuple(d -> d==dims′ ? OneTo(size(A,d)) : axiskeys(A,d), ndims(A))
    KeyedArray(data, map(copy, new_keys))
end
function Base.sort(A::KeyedVector; kw...)
    perm = sortperm(parent(A); kw...)
    KeyedArray(parent(A)[perm], (axiskeys(A,1)[perm],))
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
    d = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
    d isa Tuple{Int} && return sortslices(A; dims=first(d), kw...)
    d isa Int || throw(ArgumentError("sortslices(::KeyedArray; dims) only works along one dimension"))
    perms = ntuple(ndims(A)) do i
        i!=d && return Colon()
        sortperm(collect(eachslice(parent(A), dims=d)); by=by, kw...)
    end
    new_keys = map(getindex, axiskeys(A), perms)
    KeyedArray(keyless(A)[perms...], new_keys)
end

@doc sort_doc
function sortkeys(A::Union{KeyedArray, NdaKa}; dims=1:ndims(A), kw...)
    dims′ = hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
    perms = ntuple(ndims(A)) do d
        d in dims′ || return Colon()
        axiskeys(A,d) isa AbstractUnitRange && return Colon() # avoids OneTo(n) -> 1:n
        sortperm(axiskeys(A,d); kw...)
    end
    new_keys = map(getindex, axiskeys(A), perms)
    KeyedArray(keyless(A)[perms...], new_keys)
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
            unifiable_keys(axiskeys(A), axiskeys(B)) || return false
            return $fun(keyless(A), keyless(B); kw...)
        end
    end
end

Rlist = [:KeyedMatrix, :KeyedVector,
    :(NdaKa{L,T,2} where {L,T}), :(NdaKa{L,T,1} where {L,T}),
    ]
Olist = [ :AbstractMatrix, :AbstractVector, :Number,
    :(Adjoint{<:Any,<:AbstractMatrix}), :(Adjoint{<:Any,<:AbstractVector}),
    :(Transpose{<:Any,<:AbstractMatrix}), :(Transpose{<:Any,<:AbstractVector}),
    :(NamedDimsArray{L,T,1} where {L,T}), :(NamedDimsArray{L,T,2} where {L,T}),
    ]
for (Ts, Ss) in [(Rlist, Rlist), (Rlist, Olist), (Olist, Rlist)]
    for T in Ts, S in Ss # some combinations are errors, later, that's ok

        @eval Base.:*(x::$T, y::$S) = matmul(x,y)
        @eval Base.:\(x::$T, y::$S) = ldiv(x,y)
        @eval Base.:/(x::$T, y::$S) = rdiv(x,y)

    end
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
function matmul(x::AbstractVector, y::AbstractMatrix)
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
    :eigen, :eigvecs, :eigvals, :svd
    ]
    @eval LinearAlgebra.$fun(A::KeyedMatrix) = $fun(parent(A))
end
