module BibTeXingTests

using BibTeXing
using Test

@testset "BibTeXing" begin
    inp = joinpath(@__DIR__, "test1.bib")
    str = open(inp) do io; read(io, String); end
    A = tryparse(BibTeX, str)
    @test A isa BibTeX
    @test A.preamble isa AbstractVector
    @test A.strings isa AbstractDict{Symbol}
    @test A.entries isa AbstractDict{String}
    @test A.strings[:and] == ["\" and \""]
    @test A.strings[:AAp] == ["{Astronomy \\& Astrophysics}"]
    @test A.strings[:AApL] == [:AAp, "{ Letters}"]
    @test A.strings[:Foy] == ["{Foy, Renaud}"]
    @test A.strings[:Labeyrie] == ["\"Labeyrie, Antoine\""]
    @test A == A
    @test isequal(A, A)

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

end # module
