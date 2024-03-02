module OffsetArraysExt

using AxisKeys
using OffsetArrays

AxisKeys.no_offset(x::OffsetArray) = parent(x)
AxisKeys.shorttype(r::OffsetArray) = "OffsetArray(::" * shorttype(parent(r)) * ",...)"

end
