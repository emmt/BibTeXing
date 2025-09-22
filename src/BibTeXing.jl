module BibTeXing

export
    BibTeX

using DataStructures

include("compat.jl")

@public load save save!
@public fetch_key! fetch_value! fetch_piece!
@public Context nullchar fetch! findnext! next! skip! skipspaces!

include("types.jl")
include("parser.jl")
include("bibtex.jl")

function __init__()
    _init_categories()
end

end
