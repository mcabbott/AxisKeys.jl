module AdaptExt

using Adapt
using AxisKeys: KeyedArray, axiskeys

Adapt.adapt_structure(to, x::KeyedArray) =
    KeyedArray(Adapt.adapt(to, parent(x)), axiskeys(x))

end
