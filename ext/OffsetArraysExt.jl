module OffsetArraysExt

using AxisKeys
using OffsetArrays

AxisKeys.no_offset(x::OffsetArray) = parent(x)
AxisKeys.shorttype(r::OffsetArray) = "OffsetArray(::" * AxisKeys.shorttype(parent(r)) * ",...)"

end
