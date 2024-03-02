module AxisKeys

include("struct.jl")
export KeyedArray, axiskeys

include("lookup.jl")

include("names.jl")
export named_axiskeys, rekey
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

if !isdefined(Base, :get_extension)
    include("../ext/AbstractFFTsExt.jl")
    include("../ext/ChainRulesCoreExt.jl")
    include("../ext/CovarianceEstimationExt.jl")
    include("../ext/InvertedIndicesExt.jl")
    include("../ext/LazyStackExt.jl")
    include("../ext/OffsetArraysExt.jl")
    include("../ext/StatisticsExt.jl")
    include("../ext/StatsBaseExt.jl")
end

end
