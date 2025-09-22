module BibTeXingTests

using BibTeXing
using Test
using Aqua

@testset "BibTeXing" begin
    inp = joinpath(@__DIR__, "test1.bib")
    str = open(inp) do io; read(io, String); end
    A = tryparse(BibTeX, str)
    @test A isa BibTeX
    @test A == A
    @test isequal(A, A)
    @test A.preamble isa AbstractVector
    @test A.preamble == [
        ["\"\\def\\leftbrace{{\\ifusingtt{\\char123}{\\ensuremath\\lbrace}}}\""],
        ["{\\def\\rightbrace{{\\ifusingtt{\\char125}{\\ensuremath\\rbrace}}}}"]]
    @test A.strings isa AbstractDict{Symbol}
    @test A.entries isa AbstractDict{String}
    @test collect(keys(A.strings)) == [:AAp, :AApL, :AApR, :AApS, :AJ, :ARAA, :ActaA, :ApJ, :ApJL, :ApJS, :and, :Foy, :Labeyrie]
    @test A.strings[:and] == ["\" and \""]
    @test A.strings[:AAp] == ["{Astronomy \\& Astrophysics}"]
    @test A.strings[:AApL] == [:AAp, "{ Letters}"]
    @test A.strings[:Foy] == ["{Foy, Renaud}"]
    @test A.strings[:Labeyrie] == ["\"Labeyrie, Antoine\""]
    key = "Foy_Labeyrie-1985-LGS"
    @test A.entries[key].type === :article
    @test A.entries[key].key == key
    @test A.entries[key][:author] === A.entries[key].fields[:author]
    @test A.entries[key][:author] == [:Foy, :and, :Labeyrie]
    @test A.entries[key][:journal] === A.entries[key].fields[:journal]
    @test A.entries[key][:journal] == [:AAp]
    @test A.entries[key][:year] === A.entries[key].fields[:year]
    @test A.entries[key][:year] == [1985]
    key = "Labeyrie-1975-Vega"
    entry = A.entries[key]
    @test entry.type === :article
    @test entry.key == key
    @test entry[:author] == [:Labeyrie]
    @test entry[:title] == ["{Interference fringes obtained on {V}ega with two optical telescopes}"]
    @test entry[:journal] == [:ApJL]
    @test entry[:year] == [1975]
    @test entry[:volume] == [196]
    @test entry[:number] == [2]
    @test entry[:pages] == ["{L71--L75}"]
    @test entry[:doi] == ["{10.1086/181747}"]
    @test entry[:adsurl] == ["{http://cdsads.u-strasbg.fr/abs/1975ApJ...196L..71L}"]

    B = @inferred BibTeXing.load(inp)
    @test B isa BibTeX
    @test typeof(B.preamble) === typeof(A.preamble)
    @test typeof(B.strings) === typeof(A.strings)
    @test typeof(B.entries) === typeof(A.entries)
    @test B == A
    @test isequal(B, A)

    tmp = tempname()
    try
        @test BibTeXing.save(tmp, A) === nothing
        @test_throws Exception BibTeXing.save(tmp, A)
        @test BibTeXing.save(tmp, A; overwrite=true) === nothing
        @test BibTeXing.save!(tmp, A) === nothing
        C = @inferred BibTeXing.load(tmp)
        @test C == A
        @test isequal(C, A)
        rm(tmp)
    catch ex
        println(stderr, "Temporary file: \"$tmp\"")
    end
end

@testset "Quality tests" begin
    Aqua.test_all(BibTeXing)
end

end # module
