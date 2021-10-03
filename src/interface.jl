# Minimal interface for LoopVectorization to work:
# https://github.com/mcabbott/Tullio.jl/issues/125

using ArrayInterface: ArrayInterface

ArrayInterface.parent_type(::Type{<:KeyedArray{T,N,A}}) where {T,N,A} = A
ArrayInterface.parent_type(::Type{<:NamedDimsArray{L,T,N,<:KeyedArray{T,N,A}}}) where {L,T,N,A} = A
