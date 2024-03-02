module InvertedIndicesExt

using AxisKeys
using InvertedIndices

# needs only Base.to_indices in struct.jl to work,
# plus this to work when used in round brackets:
AxisKeys.findindex(not::InvertedIndex, r::AbstractVector) = Base.unalias(r, not)

end
