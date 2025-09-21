module BibTeXing

export
    BibTeX,
    load,
    save,
    save!

using DataStructures

# Backward compatibility.
@static if !isdefined(Base, :Memory)
    const Memory{T} = Vector{T}
end
@static if !isdefined(Base, :isnothing)
    isnothing(::Nothing) = true
    isnothing(::Any) = false
end

include("types.jl")
include("parser.jl")
include("bibtex.jl")

function __init__()
    _init_categories()
end

end
