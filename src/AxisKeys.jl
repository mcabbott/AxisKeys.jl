module AxisKeys

include("struct.jl")
export KeyedArray, axiskeys

include("lookup.jl")

include("names.jl")
export named_axiskeys
export NamedDimsArray, dimnames, rename  # Reexport key NamedDimsArrays things

include("wrap.jl")
export wrapdims

include("selectors.jl")
export Near, Index, Interval, Not, Key

include("functions.jl")
export sortkeys

include("push.jl")

include("broadcast.jl")

include("show.jl")

include("tables.jl") # Tables.jl

include("stack.jl") # LazyStack.jl

include("fft.jl") # AbstractFFTs.jl

include("statsbase.jl") # StatsBase.jl

include("chainrules.jl")
end
