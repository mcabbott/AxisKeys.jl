
Base.summary(io::IO, x::RangeArray) = _summary(io, x)
Base.summary(io::IO, A::NamedDimsArray{L,T,N,<:RangeArray}) where {L,T,N} = _summary(io, A)

function _summary(io, x)
    if ndims(x)==1
        print(io, length(x), "-element ", _typeof(x))
    else
        print(io, join(size(x), "×"), " ", _typeof(x))
    end
    if hasnames(x)
        println(io, "\nwith named range", ndims(x)>1 ? "s:" : ":")
    else
        println(io, "\nwith range", ndims(x)>1 ? "s:" : ":")
    end
    for d in 1:ndims(x)
        if hasnames(x)
            println(io, "  ", names(x,d), " ∈ ", ranges(x,d))
        else
            println(io, "  (", d, ") ∈ ", ranges(x,d))
        end
    end
    if length(x)>0
        print(io, "and data")
    else
        print(io, "but no data.")
    end
end

_typeof(::RangeArray{T,N,AT,RT}) where {T,N,AT,RT} =
    string("RangeArray{…,", AT, ",…}")
_typeof(::RangeArray{T,N,<:NamedDimsArray{L,T,N,AT},RT}) where {T,N,L,AT,RT} =
    string("RangeArray{…,NamedDimsArray{⋯,", AT, "},…}")
