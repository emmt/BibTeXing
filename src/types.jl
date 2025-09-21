# Type of vector used to store the values of a field.
const Value = Vector{Union{Int,String,Symbol}}

struct Entry
    type::Symbol # :article, :book, etc.
    key::String
    fields::Dict{Symbol,Value}
    Entry(type::Symbol, key::AbstractString) =
        new(type, key, Dict{Symbol,Value}())
end

# 2ms with OrderedDict instead of 1.5ms
struct BibTeX
    preamble::Vector{Value}
    strings::OrderedDict{Symbol,Value}
    entries::OrderedDict{String,Entry}
end

mutable struct Context{S<:AbstractString}
    string::S
    index::Int # index to next character to parse
    stop::Int # index of last valid character
    line::Int # line counter

    # Private "unsafe" inner constructor.
    global _Context
    _Context(str::S, start::Int, stop::Int, line::Int) where {S<:AbstractString} =
        new{S}(str, start, stop, line)
end

struct ParseError{C<:Context,S<:AbstractString}
    context::C
    message::S
end

# Private singleton for undefined thing.
struct Undefined end
