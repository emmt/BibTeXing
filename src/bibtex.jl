"""
    bib = BibTeX()

Return an empty BibTeX database.

"""
BibTeX() = BibTeX(Vector{Value}(undef, 0),
                  OrderedDict{Symbol,Value}(),
                  OrderedDict{String,Entry}())

"""
    bib = BibTeX(str)
    bib = parse(BibTeX, str)
    bib = tryparse(BibTeX, str)

Convert string `str` into a BibTeX database.

The returned object has the following content:

    bib.preamble            # vector of preamble values

    bib.strings             # ordered dictionary of string definitions
    bib.strings[ident]      # value corresponding to ident

    bib.entries             # ordered dictionary of entries
    bib.entries[key]        # entry for BibTeX key
    bib.entries[key].type   # entry type, e.g. `:article` or `:book`
    bib.entries[key].key    # entry key
    bib.entries[key].fields[field] # value of field in entry for BibTeX key
    bib.entries[key][field] # idem

The following conventions apply:

- A BibTeX `key` is a string.

- Entry types and field names (denoted by `type` and `field` above) are `Symbol`s in
  lowercase letters (however they are capitalized in `str`).

- String identifiers (denoted by `ident` above) are symbolic strings with cases preserved.

- A BibTeX *value* is stored as a vector of pieces of value. Each piece of value is either a
  `String` (enclosed in braces or in double quotes), a `Symbol` to be replaced by the
  corresponding string definition (itself a *value*), or an integer. The value is the
  concatenation of these pieces (after proper substitutions and conversions).

See also [`BibTeXing.load`](@ref) and [`BibTeXing.save].

"""
BibTeX(s::Union{AbstractString,Context}; kwds...) = parse(BibTeX, s; kwds...)

BibTeX(io::IO; kwds...) = read(io, BibTeX; kwds...)

Base.read(io::IO, ::Type{BibTeX}; kwds...) = parse(BibTeX, read(io, String); kwds...)

Base.haskey(entry::Entry, field::Symbol) = haskey(entry.fields, field)
Base.get(entry::Entry, field::Symbol, def) = get(entry.fields, field, def)
Base.getindex(entry::Entry, field::Symbol) = getindex(entry.fields, field)
Base.setindex!(entry::Entry, valule, field::Symbol) = setindex(entry.fields, value, field)

for func in (:(==), :isequal)
    @eval begin
        function Base.$func(A::BibTeX, B::BibTeX)
            return A === B || ($func(A.preamble, B.preamble) &&
                compare($func, A.strings, B.strings) &&
                compare($func, A.entries, B.entries))
        end

        function Base.$func(A::Entry, B::Entry)
            return A === B || ($func(A.type, B.type) &&
                $func(A.key, B.key) &&
                compare($func, A.fields, B.fields))
        end
    end
end

function compare(f::Union{typeof(==),typeof(isequal)},
                 A::AbstractDict, B::AbstractDict)
    # Check that all keys of A are in B.
    for key in keys(A)
        haskey(B, key) || return false
    end
    # Check that all keys of B are in A and that the associated values are the same
    # (according to f).
    for (key, val) in B
        f(val, get(A, key, Undefined())) || return false
    end
    return true
end

"""
    BibTeXing.load(filename; kwds...) -> bib::BibTeX

Load BibTeX file `filename` and return its content as a [`BibTeX`](@ref) object. Keywords
`kwds...` are passed to the parser.

See also [`BibTeXing.save].

"""
load(filename::AbstractString; kwds...) =
    open(filename, "r") do io; read(io, BibTeX; kwds...); end

"""
    BibTeXing.save!(filename, bib::BibTeX; kwds...)

Save bibliography `bib` into BibTeX file `filename` which may already exists. This is like
specfying `overwrite=true` in [`BibTeXing.save]. Other keywords are passed to
[`BibTeXing.save].

"""
save!(filename::AbstractString, bib::BibTeX; kwds...) =
    save(filename, bib; kwds..., overwrite=true)

"""
    BibTeXing.save(filename, bib::BibTeX; overwrite=false, opening='{')

Save bibliography `bib` into BibTeX file `filename`.

Keyword `overwrite` specifies whether `filename` can be overwritten if it exists.

Keyword `opening` specifies the character to use, `'{'` or `'('`, to surround entry content.

See also [`BibTeX`](@ref), [`BibTeXing.save!], and [`BibTeXing.load].

"""
function save(filename::AbstractString, bib::BibTeX;
              overwrite::Bool = false,
              opening::Char = '{')
    overwrite || !ispath(filename) || error("file $(repr(filename)) already exists")
    closing =
        opening == '{' ? '}' :
        opening == '(' ? ')' : throw(ArgumentError(
            "opening character must be '{' or '(', got $(repr(opening))"))
    open(filename, "w") do io
        print(io, "% Encoding: UTF-8\n")
        for value in bib.preamble
            print(io, "\n@preamble", opening, ' ')
            save_value(io, value)
            print(io, ' ', closing)
        end
        isempty(bib.preamble) || print(io, '\n')
        for (name, value) in bib.strings
            print(io, "\n@string", opening, ' ', name, " = ")
            save_value(io, value)
            print(io, ' ', closing)
        end
        isempty(bib.strings) || print(io, '\n')
        for (key, entry) in bib.entries
            print(io, "\n@", entry.type, opening, key)
            # TODO better sorting method
            for field in sort(collect(keys(entry.fields)))
                print(io, ",\n    ", field, " = ")
                save_value(io, entry[field])
            end
            isempty(entry.fields) || print(io, '\n')
            print(io, closing, '\n')
        end
    end
    return nothing
end

# TODO make Value a specific type and extend Base.show and/or Base.print.
function save_value(io::IO, value::Value)
    separator = false
    for piece in value
        separator && print(io, " # ")
        print(io, piece)
        separator = true
    end
    return nothing
end

to_string(value::Value, bib::BibTeX) = to_string(value, bib.strings)

function to_string(value::Value, strings::OrderedDict{Symbol,Value})
    buf = IOBuffer()
    _to_string(buf, value, strings)
    return String(take!(buf))
end

function _to_string(buf::IOBuffer, value::Value, strings::OrderedDict{Symbol,Value})
    for piece in value
        _to_string(buf, piece, strings)
    end
    return buf
end

_to_string(buf::IOBuffer, val::Integer, strings::OrderedDict{Symbol,Value}) =
    print(buf, val)

function _to_string(buf::IOBuffer, sym::Symbol, strings::OrderedDict{Symbol,Value})
    val = get(strings, sym, Undefined())
    val isa Undefined && error("undefined BibTeX string `$sym`")
    return _to_string(buf, val, strings)
end

# FIXME some braces must be kept
function _to_string(buf::IOBuffer, str::AbstractString,
                    strings::OrderedDict{Symbol,Value})
    start, stop = firstindex(str), lastindex(str)
    start <= stop || return
    opening = @inbounds str[start]
    closing = @inbounds str[stop]
    (opening == '"' && closing == '"') || (opening == '{' && closing == '}') || error(
        "invalid BibTeX string, should be \"…\" or {…}")
    cnt = 0
    i = nextind(str, start)
    while i < stop
        c = @inbounds str[i]
        if c == '{'
            cnt += 1
        elseif c == '}'
            (cnt -= 1) >= 0 || break
        else
            write(buf, c)
        end
        i = nextind(str, i)
    end
    cnt > 0 && error("too many {'s in BibTeX string")
    cnt < 0 && error("too many }'s in BibTeX string")
    return buf
end

#---------------------------------------------------------------------------------- PARSER -
#
# BibTeX grammar (see https://github.com/aclements/biblib#recognized-grammar) is defined
# by:
#
#     comment = '@' 'comment'
#
#     preamble = '@' 'preamble' ( '{' value '}' |
#                                 '(' value ')' )
#
#     string = '@' 'string' ( '{' ident '=' value '}' |
#                             '(' ident '=' value ')' )
#
#     entry = '@' ident ( '{' key (',' ident '=' value)* ','? '}' |
#                         '(' key (',' ident '=' value)* ','? ')' )
#
#     value = piece ( '#' piece )*
#
#     piece = [0-9]+
#           | '{' balanced* '}'
#           | '"' ([^"] balanced)* '"'
#           | ident
#
#     balanced = '{' balanced* '}'
#              | [^{}]
#
#     key = [^\t\n ,}]+
#
#     ident = first_ident_char ( [0-9] | first_ident_char )*
#
#     first_ident_char = [^\t\n "'#%(),={}]
#
# Above, '…' denotes a literal string, PAT1 | PAT2 means pattern PAT1 or PAT2, parentheses
# (…) are used to group patterns, PAT* is any number of pattern PAT, PAT+ is at least one
# pattern PAT, PAT? is at most one pattern PAT, […] denotes a list of characters, [^…]
# denotes a list of characters to exclude. Any number of white spaces can appear between
# tokens.
#
# Anything not matching `'@' ident` is treated as a comment (i.e. ignored).
#
# Entry and field names (i.e. `ident` tokens after the '@' or before the '=')
# are case insensitive. These are converted to lowercase and stored as `Symbol`s by the
# parser. BibTeX will complain if two entries have the same internal key, even if they
# aren’t capitalized in the same way (Nicolas Markey in "Tame the BeaST").
#

function Base.tryparse(::Type{BibTeX}, s::Union{AbstractString,Context}; kwds...)
    try
        return parse(BibTeX, s; kwds...)
    catch
        return nothing
    end
end

Base.parse(::Type{BibTeX}, s::AbstractString; kwds...) =
    parse(BibTeX, Context(s); kwds...)

function Base.parse(::Type{BibTeX}, ctx::Context; debug::Bool=false)
    bib = BibTeX()
    while findnext!('@', ctx)
        # Get type of entry.
        type = fetch_ident!(skipspaces!(ctx))
        isnothing(type) && continue
        type = Symbol(lowercase(type))
        debug && println(stderr, "got entry \"@$type\" at line $(ctx.line)")
        type === :comment && continue # skip until next '@'

        # Find opening brace or parenthesis and infer closing character.
        skipspaces!(ctx)
        opening = eof(ctx) ? '\0' : (@inbounds ctx[])
        closing =
            opening == '{' ? '}' :
            opening == '(' ? ')' :
            throw(ParseError(ctx, "expecting '{' or '(' after \"@$type\""))
        skipspaces!(next!(ctx)) # skip opening character and following spaces

        # Parse entry content.
        if type === :preamble
            value = fetch_value!(ctx)
            isempty(value) || push!(bib.preamble, value)
            startswith(skipspaces!(ctx), closing) || throw(ParseError(
                ctx, "expecting '$closing' after \"@$type$opening…\" entry"))
        elseif type === :string
            name = fetch_ident!(ctx)
            isnothing(name) && throw(ParseError(
                ctx, "expecting name after \"@$type$opening\""))
            name = Symbol(name)
            haskey(bib.strings, name) && throw(ParseError(
                ctx, "duplicate `@string` name \"$name\""))
            startswith(skipspaces!(ctx), '=') || throw(ParseError(
                ctx, "expecting '=' after \"@$type{$name\""))
            value = fetch_value!(skipspaces!(next!(ctx)))
            isempty(value) && throw(ParseError(
                ctx, "empty value after \"@$type{$name = \""))
            startswith(skipspaces!(ctx), closing) || throw(ParseError(
                ctx, "expecting '$closing' after \"@$type$opening$name = …\" entry"))
            bib.strings[name] = value
        else
            bibkey = fetch_key!(ctx)
            isnothing(bibkey) && throw(ParseError(
                ctx, "expecting BibTeX key after \"@$type{\""))
            haskey(bib.entries, bibkey) && throw(ParseError(
                ctx, "duplicate BibTeX key \"$bibkey\""))
            entry = Entry(type, bibkey)
            bib.entries[bibkey] = entry
            while startswith(skipspaces!(ctx), ',')
                field = fetch_ident!(skipspaces!(next!(ctx)))
                isnothing(field) && break
                field = Symbol(lowercase(field))
                haskey(entry.fields, field) && throw(ParseError(
                    ctx, "duplicate field \"$field\" in \"$bibkey\" entry"))
                startswith(skipspaces!(ctx), '=') || throw(ParseError(
                    ctx, "expecting '=' after field \"$field\" in \"$bibkey\" entry"))
                value = fetch_value!(skipspaces!(next!(ctx)))
                isnothing(value) && break
                entry.fields[field] = value
            end
            startswith(skipspaces!(ctx), closing) || throw(ParseError(
                ctx, "expecting '$closing' in \"$bibkey\" entry"))
        end
    end
    return bib
end

#-------------------------------------------------------------------------- PARSER METHODS -

"""
    BibTeXing.fetch_key!(ctx) -> key

Fetch next BibTeX key in context `ctx` starting at its current index. If a key is found, the
index in `ctx` is positioned after the last key character and the key is returned as a
sub-string. Otherwise, if nokey is found, the index of `ctx` is left unchanged and `nothing`
is returned.

"""
fetch_key!(ctx::Context) = fetch!(is_key, ctx)

fetch_ident!(ctx::Context) = fetch!(is_ident_1st, is_ident, ctx)

"""
    BibTeXing.fetch_value!(ctx) -> value

Fetch BibTeX value starting at the current index in context `ctx`. A BibTeX value is a
sequence of pieces of value separated by a `'#'` character. The context index is positioned
at the first non-space character after the sequence and a vector of pieces of value
(possibly empty) is returned.

"""
function fetch_value!(ctx::Context)
    index = ctx.index
    value = Value(undef, 0)
    while true
        piece = fetch_piece!(ctx)
        if isnothing(piece)
            # Restore index at the first non-space character that is not part of the
            # sequence.
            ctx.index = index
            break
        end
        push!(value, piece)
        startswith(skipspaces!(ctx), '#') || break
        index = ctx.index # remember index of '#'
        skipspaces!(next!(ctx))
    end
    return value
end

"""
    BibTeXing.fetch_piece!(ctx) -> piece

Fetch piece of BibTeX value starting at current index of context `ctx`. If a piece of value
is found, the index of `ctx` is moved at the first character after the value and return a
string (for quoted or braced string token), an integer (for a literal number), or a symbol
(for a macro name). If no value is found, the index of `ctx` is left unchanged and `nothing`
is returned.

"""
function fetch_piece!(ctx::Context)
    s, i, n = ctx.string, ctx.index, ctx.stop
    i > n && return nothing
    c = @inbounds s[i]
    if c == '"'
        # A quoted string.
        i1 = i
        cnt = 0
        while true
            i = nextind(s, i)
            i > n && return nothing
            c = @inbounds s[i]
            if c == '{'
                cnt += 1
            elseif c == '}'
                cnt -= 1
                cnt < 0 && return nothing
            elseif cnt == 0 && c == '"'
                ctx.index = nextind(s, i)
                return String(@inbounds SubString(s, i1, i))
            elseif c == '\n' || c == '\r'
                return nothing
            end
        end
    elseif c == '{'
        # A braced string.
        i1 = i
        cnt = 1
        while true
            i = nextind(s, i)
            i > n && return nothing
            p = c # preceding character
            c = @inbounds s[i]
            if c == '{'
                cnt += 1
            elseif c == '}'
                cnt -= 1
                if cnt == 0
                    ctx.index = nextind(s, i)
                    return String(@inbounds SubString(s, i1, i))
                elseif cnt < 0
                    return nothing
                end
            elseif c == '\r' || (c == '\n' && p != '\r')
                ctx.line += 1
            end
        end
    elseif is_digit(c)
        # A decimal number.
        val = Int(c - '0')
        while true
            i = nextind(s, i)
            i > n && break
            c = @inbounds s[i]
            is_digit(c) || break
            old = val
            val = Int(c - '0') + 10*val
            if val < old
                ctx.index = i
                throw(ParseError(ctx, "integer overflow"))
            end
        end
        ctx.index = i
        return val
    elseif is_ident_1st(c)
        # A macro name.
        i1 = i2 = i
        while true
            i = nextind(s, i)
            i > n && break
            c = @inbounds s[i]
            is_ident(c) || break
            i2 = i
        end
        ctx.index = i
        return Symbol(@inbounds SubString(s, i1, i2))
    else
        # An unexpected character.
        return nothing
    end
end

#-------------------------------------------------------------------- CHARACTER CATEGORIES -

const Category = UInt8
const _CATEGORY = Vector{Category}(undef, 128)
const NONE      = zero(Category)
const IDENT_1ST = (one(Category) << 0)::Category
const IDENT     = (one(Category) << 1)::Category
const KEY       = (one(Category) << 3)::Category

#= NOTE
iscntrl(c::AbstractChar) = c <= '\x1f' || '\x7f' <= c <= '\u9f'
@inline isspace(c::AbstractChar) =
    c == ' ' || '\t' <= c <= '\r' || c == '\u85' ||
    '\ua0' <= c && category_code(c) == UTF8PROC_CATEGORY_ZS
isdigit(c::AbstractChar) = (c >= '0') & (c <= '9')
isletter(c::AbstractChar) = UTF8PROC_CATEGORY_LU <= category_code(c) <= UTF8PROC_CATEGORY_LO
=#

is_space(c::AbstractChar) = isspace(c)
is_digit(c::AbstractChar) = ('0' <= c) & (c <= '9')
for (func, bits) in (:is_key => KEY, :is_ident_1st => IDENT_1ST, :is_ident => IDENT)
    @eval @inline $func(c::AbstractChar) = !iszero(category(c) & $bits)
end

to_uint32(c::AbstractChar) = UInt32(c)
to_uint32(c::Char) = bswap(reinterpret(UInt32, c))
#to_uint32(c::Char) = bswap(Core.Intrinsics.bitcast(UInt32, c))

function category(c::AbstractChar)
    u = to_uint32(c)
    return if u < 0x80
        # `c` is ASCII
        @inbounds _CATEGORY[(u % Int)::Int + 1]
    else
        # We know `c` is not a decimal digit.
        isletter(c) || !(isspace(c) && iscntrl(c)) ? (IDENT_1ST|IDENT|KEY) : NONE
    end
end

function _init_categories()
    global _CATEGORY
    @assert firstindex(_CATEGORY) == 1
    @assert lastindex(_CATEGORY) >= 128

    function _category_index(c::AbstractChar)
        u = to_uint32(c)
        u < 0x80 || throw(ArgumentError("non ASCII character"))
        return (u % Int)::Int + 1
    end

    # Clear all bits.
    fill!(_CATEGORY, NONE)

    # An identifier or a key is any characters in \x21:\x7f except a few others that are
    # cleared below.
    for c in '\x21':'\x7f'
        _CATEGORY[_category_index(c)] = KEY | IDENT_1ST | IDENT
    end

    # Identifiers do not start with a digit.
    for c in '0':'9'
        _CATEGORY[_category_index(c)] &= ~IDENT_1ST
    end

    # Clear non-space characters not in an identifier.
    for c in "\"#%'(),={}"
        _CATEGORY[_category_index(c)] &= ~(IDENT_1ST | IDENT)
    end

    # Clear non-space characters not in a key.
    for c in ",}"
        _CATEGORY[_category_index(c)] &= ~KEY
    end

    return nothing
end
