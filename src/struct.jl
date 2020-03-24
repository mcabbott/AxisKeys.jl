using Base: @propagate_inbounds, OneTo, RefValue

struct KeyedArray{T,N,AT,KT} <: AbstractArray{T,N}
    data::AT
    keys::KT
end

const KeyedVector{T,AT,RT} = KeyedArray{T,1,AT,RT}
const KeyedMatrix{T,AT,RT} = KeyedArray{T,2,AT,RT}
const KeyedVecOrMat{T,AT,RT} = Union{KeyedVector{T,AT,RT}, KeyedMatrix{T,AT,RT}}

function KeyedArray(data::AbstractArray{T,N}, keys::Tuple) where {T,N}
    construction_check(data, keys)
    KeyedArray{T, N, typeof(data), typeof(keys)}(data, keys)
end
function KeyedArray(data::AbstractVector{T}, keys::RefValue{<:AbstractVector}) where {T}
    construction_check(data, (keys[],))
    KeyedArray{T, 1, typeof(data), typeof(keys)}(data, keys)
end
KeyedArray(data::AbstractVector, tup::Tuple{AbstractVector}) =
    KeyedArray(data, Ref(first(tup)))
KeyedArray(data::AbstractVector, arr::AbstractVector) =
    KeyedArray(data, Ref(arr))

function construction_check(data::AbstractArray, keys::Tuple)
    length(keys) == ndims(data) || throw(ArgumentError(
        "wrong number of key vectors, got $(length(keys)) with ndims(A) == $(ndims(data))"))
    keys isa Tuple{Vararg{AbstractVector}} || throw(ArgumentError(
        "key vectors must all be AbstractVectors"))
    map(v -> axes(v,1), keys) == axes(data) || throw(ArgumentError(
        "lengths of key vectors must match those of axes"))
end

function KeyedArray(A::KeyedArray, k2::Tuple)
    k3 = unify_keys(axiskeys(A), k2)
    KeyedArray(parent(A), k3)
end

Base.size(x::KeyedArray) = size(parent(x))

Base.axes(x::KeyedArray) = axes(parent(x))

Base.parent(x::KeyedArray) = getfield(x, :data)
keyless(x::KeyedArray) = parent(x)
keyless(x) = x

axiskeys(x::KeyedArray) = getfield(x, :keys)
axiskeys(x::KeyedVector) = tuple(getindex(getfield(x, :keys)))
# avoiding Tuple(Ref()) as it's slow, https://github.com/JuliaLang/julia/pull/33674
axiskeys(x::KeyedArray, d::Int) = d<=ndims(x) ? getindex(axiskeys(x), d) : OneTo(1)
axiskeys(x::KeyedVector, d::Int) = d==1 ? getindex(getfield(x, :keys)) : OneTo(1)

Base.IndexStyle(A::KeyedArray) = IndexStyle(parent(A))

Base.eachindex(A::KeyedArray) = eachindex(parent(A))

Base.keys(A::KeyedArray) = error("Base.keys(::KeyedArray) not defined, please open an issue if this happens unexpectedly.")

for (get_or_view, key_get, maybe_copy) in [
        (:getindex, :keys_getindex, :copy),
        (:view, :keys_view, :identity)
    ]
    @eval begin

        @inline function Base.$get_or_view(A::KeyedArray, raw_inds...)
            raw_inds = selector_indices(A, raw_inds) # unsure, tweaking in the merge

            inds = to_indices(A, raw_inds)
            @boundscheck checkbounds(parent(A), inds...)
            data = @inbounds $get_or_view(parent(A), inds...)
            data isa AbstractArray || return data # scalar output

            raw_keys = $key_get(axiskeys(A), inds)
            raw_keys === () && return data # things like A[A .> 0]

            new_keys = ntuple(ndims(data)) do d
                raw_keys === nothing && return axes(data, d)
                raw_keys[d]
            end
            KeyedArray(data, new_keys)
        end

        # drop all, for A[:] and A[A .> 0] with ndims>=2
        @inline $key_get(keys::Tuple{Any, Any, Vararg{Any}}, inds::Tuple{Base.LogicalIndex}) = ()
        @inline $key_get(keys::Tuple{Any, Any, Vararg{Any}}, inds::Tuple{Base.Slice}) = ()

        # drop one, for integer index
        @inline $key_get(keys::Tuple, inds::Tuple{Integer, Vararg{Any}}) =
            $key_get(tail(keys), tail(inds))

        # from a Colon, k[:] would copy too, but this avoids view([1,2,3], :)
        @inline $key_get(keys::Tuple, inds::Tuple{Base.Slice, Vararg{Any}}) =
            ($maybe_copy(first(keys)), $key_get(tail(keys), tail(inds))...)

        # this avoids making views of 1:10 etc, they are immutable anyway
        @inline function $key_get(keys::Tuple, inds::Tuple{AbstractVector, Vararg{Any}})
            got = if first(keys) isa AbstractRange
                @inbounds getindex(first(keys), first(inds))
            else
                @inbounds $get_or_view(first(keys), first(inds))
            end
            (got, $key_get(tail(keys), tail(inds))...)
        end

        # newindex=[CartesianIndex{0}()], uses up one ind, sets N keys to default i.e. axes
        @inline function $key_get(keys::Tuple, inds::Tuple{AbstractVector{CartesianIndex{0}}, Vararg{Any}})
            (OneTo(1), $key_get(keys, tail(inds))...)
        end
        @inline function $key_get(keys::Tuple, inds::Tuple{AbstractVector{CartesianIndex{N}}, Vararg{Any}}) where {N}
            _, keys_left = Base.IteratorsMD.split(keys, Val(N))
            (ntuple(_->nothing, N)..., $key_get(keys_left, tail(inds))...)
        end

        # terminating case, trailing 1s (already checked) could be left over
        @inline $key_get(keys::Tuple{}, inds::Tuple{}) = ()
        @inline $key_get(keys::Tuple{}, inds::Tuple{Integer, Vararg{Any}}) = ()

    end
end

@inline function Base.setindex!(A::KeyedArray, val, raw_inds...)
    I = Base.to_indices(A, raw_inds)
    @boundscheck checkbounds(A, I...)
    @inbounds setindex!(parent(A), val, I...)
    val
end

@inline function Base.dotview(A::KeyedArray, raw_inds...)
    I = Base.to_indices(A, raw_inds)
    @boundscheck checkbounds(A, I...)
    @inbounds setindex!(parent(A), val, I...)
    val
end
