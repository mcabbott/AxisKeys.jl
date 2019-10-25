
Base.summary(io::IO, x::RangeArray) = _summary(io, x)
Base.summary(io::IO, A::NamedDimsArray{L,T,N,<:RangeArray}) where {L,T,N} = _summary(io, A)

function _summary(io, x)
    if ndims(x)==1
        print(io, length(x), "-element ", typeof(x))
    else
        print(io, join(size(x), " × "), " ", typeof(x))
    end
    println(io, "\nwith range", ndims(x)>1 ? "s:" : ":")
    for d in 1:ndims(x)
        if hasnames(x)
            println(io, "  ", names(x,d), " ∈ ", ranges(x,d))
        else
            println(io, "  (", d, ") ∈ ", ranges(x,d))
        end
    end
    print(io, "and data")
end
