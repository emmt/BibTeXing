# BibTeXing

[![Build Status](https://github.com/emmt/BibTeXing.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/emmt/BibTeXing.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/emmt/BibTeXing.jl?svg=true)](https://ci.appveyor.com/project/emmt/BibTeXing-jl)
[![Coverage](https://codecov.io/gh/emmt/BibTeXing.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/emmt/BibTeXing.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

*BibTeXing* is a [Julia](https://julialang.org) package for managing bibliography in
[BibTeX](https://en.wikipedia.org/wiki/BibTeX) format.

## Usage

To read a BibTeX bibliography from file `filename`, execute:

``` julia
bib = BibTeXing.load(filename)
```

If the bibliography (in BibTeX format) is stored in string `str`, then one of the following
can be used to parse the string:

``` julia
bib = BibTeX(str)
bib = parse(BibTeX, str)
bib = tryparse(BibTeX, str)
```

The only difference is that the latter returns `nothing` in case of error while the two
former throw a `BibTeXing.ParseError` exception.

The `bib` object (of type `BibTeX`) has the following content:

- `bib.preamble` is a vector of preamble *values* built from the `@preamble` entries of the
   BibTeX database.

- `bib.strings` is an ordered dictionary of string definitions built from the `@string`
   entries of the BibTeX database; `bib.strings[ident]` is the *value* corresponding to the
   identifier `ident` (a `Symbol`);

- `bib.entries` is an ordered dictionary of entries and `bib.entries[key]` is the entry for
  BibTeX `key` (a `String`) with the following properties:

  - `bib.entries[key].type` is a `Symbol` set with the entry type like `:article` or `:book`
    (always in lowercase letters, even if the entry type is written with uppercase letters
    in the source);
  - `bib.entries[key].key` is the BibTeX key of the entry (a `String`);
  - `bib.entries[key].fields` is a dictionary of fields indexed by their symbolic names like
    `:author`, `:title`, or `:year` (also in lowercase letters, even if they are written
    with uppercase letters in the source file);

To get the *value* of a field in a BibTeX entry, write:

``` julia
bib.entries[key].fields[field]
```

or for short:

``` julia
bib.entries[key][field]
```

In order to preserve the structure of the BibTeX database, a BibTeX *value* is stored as a
vector of pieces of value. Each piece of value is either a `String` (enclosed in braces or
in double quotes), a `Symbol` to be replaced by the corresponding string definition (itself
a *value*), or an integer. The value is the concatenation of these pieces (after proper
substitutions and conversions).

To write a BibTeX database `bib` into the file `filename`, call:

``` julia
BibTeXing.save(filename, bib)
```

You may want to specify the keyword `overwrite=true` to (silently) overwrite `filename` if
it exists. Another solution is to call:

``` julia
BibTeXing.save!(filename, bib)
```


## Links

In his tutorial [*Tame the
BeaST*](https://tug.ctan.org/info/bibtex/tamethebeast/ttb_en.pdf), Nicolas Markey provides
many useful explanations and tricks about BibTeX files. In particular, he suggests to use
`@string` definitions for author's names in order to avoid misspelling (*Section 11. The
`author` field*). Personally, I also use `@string` definitions for journal names to deal
with the various abbreviations used by editors. These are some of the reasons to preserve
the structure of a BibTeX database.

A description of BibTeX grammar is provided [here](https://github.com/aclements/biblib#recognized-grammar).

To my knowledge, there exist the following Julia packages for dealing with BibTeX files:

- [Bibliography.jl](https://github.com/Humans-of-Julia/Bibliography.jl) which however fails
  to load BibTeX files if an entry field uses an `@string` definition (see examples in the
  [test](./test) directory).

- [BibTeX.jl](https://github.com/JuliaTeX/BibTeX.jl) which however convert all values into
  simple strings hence loosing part of the logic of the BibTeX database.
