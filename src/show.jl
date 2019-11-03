
Base.summary(io::IO, x::RangeArray) = _summary(io, x)
Base.summary(io::IO, A::NamedDimsArray{L,T,N,<:RangeArray}) where {L,T,N} = _summary(io, A)

function _summary(io, x)
    if ndims(x)==1
        print(io, length(x), "-element ")
    else
        print(io, join(size(x), "×"), " ")
    end
    showtype(io, x)
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

showtype(io::IO, ::RangeArray{T,N,AT}) where {T,N,AT} =
    print(io, "RangeArray{…,", AT, ",…}")
showtype(io::IO, ::RangeArray{T,N,<:NamedDimsArray{L,T,N,AT}}) where {T,N,L,AT} =
    print(io, "RangeArray{…,NamedDimsArray{…,", AT, "},…}")
showtype(io::IO, ::NamedDimsArray{L,T,N,<:RangeArray{T,N,AT}}) where {T,N,L,AT} =
    print(io, "NamedDimsArray{…,RangeArray{…,", AT, "},…}")

function showtype(io::IO, x::RangeArray{T,N,<:SubArray{T,N,AT}}) where {T,N,AT}
    print(io, "RangeArray{…,view(", AT)
    Base.showindices(io, x.data.indices...)
    print(io, ")}")
end
function showtype(io::IO, x::RangeArray{T,N,<:NamedDimsArray{L,T,N,<:SubArray{T,N,AT}}}) where {T,N,L,AT}
    print(io, "RangeArray{…,NamedDimsArray{…,view(", AT)
    Base.showindices(io, x.data.data.indices...)
    print(io, ")},…}")
end
