module BibTeXing

export
    BibTeX,
    load,
    save,
    save!

using DataStructures

include("compat.jl")
include("types.jl")
include("parser.jl")
include("bibtex.jl")

function __init__()
    _init_categories()
end

end
