module AxisRanges

include("struct.jl")

export RangeArray, ranges, wrapdims

include("names.jl")

export NamedDimsArray, namedranges, namedaxes

include("selectors.jl")

export All, Near, Between, Index

include("functions.jl")

include("push.jl")

include("broadcast.jl")

include("show.jl")

include("notpiracy.jl")

end
