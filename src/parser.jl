# Methods for implementing a simple parser.

"""
    ctx = BibTeXing.Context(str; start=firtsindex(str), stop=lastindex(str), line=1)
    ctx = BibTeXing.Context(str, start:stop; line=1)

Build a parser context over string `str` for index range `start:stop` and with `line` the
number of lines of the first line in `str` starting at `start`.

Properties:

 - `ctx.string` is the string to parse;
 - `ctx.index` is the index to the next unparsed character, it should always be a valid
   index or equal to `ctx.stop + 1`;
 - `ctx.stop` is the index to the last character to parse.

If `ctx.index > `ctx.stop`, there are no more characters to parse. This is tested by
`eof(ctx)`.

`ctx[]` and `peek(ctx)` yield the character at current index or `'\0'` if there are no more
character to parse.

See also [`BibTeXing.fetch!`](@ref), [`BibTeXing.findnext!`](@ref),
[`BibTeXing.next!`](@ref), [`BibTeXing.skip!`](@ref), and [`BibTeXing.skipspaces!`](@ref).

"""
function Context(str::AbstractString;
                 start::Union{Undefined,Integer} = Undefined(),
                 stop::Union{Undefined,Integer} = Undefined(),
                 line::Integer = 1)
    _start, _stop = firstindex(str)::Int, lastindex(str)::Int
    if (start isa Integer ? start : _start) > (stop isa Integer ? stop : _stop)
        # Empty sub-string. NOTE ctx.stop is always a valid index.
        _start = _stop + 1
    else
        if start isa Integer
            isvalid(str, start) || throw(ArgumentError(
                "invalid string index `start=$start`"))
            _start = Int(start)::Int
        end
        if stop isa Integer
            isvalid(str, stop) || throw(ArgumentError(
                "invalid string index `stop=$stop`"))
            _stop = Int(stop)::Int
        end
    end
    _str, off = unveil_substring(str)
    return _Context(_str, _start + off, _stop + off, Int(line)::Int)
end
function Context(str::AbstractString, rng::AbstractUnitRange{<:Integer};
                 line::Integer = 1)
    return Context(str; start=first(rng), stop=last(rng), line=line)
end

unveil_substring(str::AbstractString, off::Int=0) = str, off
@inline unveil_substring(str::SubString, off::Int=0) =
    unveil_substring(unveil_substring(str.string, str.offset + off)...)

@inline Base.eof(ctx::Context) = ctx.index > ctx.stop
@inline Base.peek(ctx::Context) =
    1 ≤ ctx.index ≤ ctx.stop ? (@inbounds ctx.string[ctx.index]) : nullchar(ctx)

@inline Base.getindex(ctx::Context) = peek(ctx)

"""
    c = BibTeXing.nullchar(x)
    c = BibTeXing.nullchar(typeof(x))

Return the *null character* for object `x`. This is a *trait* which only depends on the type
of `x`.

"""
nullchar(x::Union{AbstractChar,AbstractString,Context}) = nullchar(typeof(x))
nullchar(::Type{C}) where {C<:AbstractChar} = C(0x00)::C
nullchar(::Type{S}) where {S<:AbstractString} = nullchar(eltype(S))
nullchar(::Type{<:Context{S}}) where {S<:AbstractString} = nullchar(eltype(S))

function Base.show(io::IO, ctx::Context)
    # Retrieve string, index, and index bounds from context.
    str = ctx.string
    start = firstindex(str)
    stop = ctx.stop
    index = clamp(ctx.index, start - 1, stop + 1)

    # Print prefix.
    ellipsis = "[…]"
    prefix = "BibTeXing.Context(\""
    write(io, prefix)
    align = length(prefix) # position of '^' on 2nd line
    if index > start
        # Print preceding characters in a buffer to measure the number of printed characters
        # and adjust alignment accordingly.
        let i = prevind(str, index), j = i, n = 1, buf = IOBuffer()
            while i > start && n < 20 # <- max. number of previous characters
                i = prevind(str, i)
                n += 1
            end
            i > start && write(buf, ellipsis)
            write(buf, SubString(str, i, j))
            temp = escape_string(String(take!(buf)))
            write(io, temp)
            align += length(temp)
        end
    elseif index < start
        # Adjust alignment to have '^' under the opening '"'.
        align -= 1
    end
    if max(start, index) ≤ stop
        # Print current and next characters.
        let i = max(start, index), j = i, n = 0
            while j < stop && n < 20 # <- max. number of next characters
                j = nextind(str, j)
                n += 1
            end
            write(io, escape_string(SubString(str, i, j)))
            j < stop && write(io, ellipsis)
        end
    end
    write(io, "\")\n") # end of 1st line

    # Print pointer position.
    for _ in 1:align
        write(io, '─')
    end
    write(io, "╯\n") # possible markers: ^ ╯ ╜
    return nothing
end

function Base.showerror(io::IO, err::ParseError)
    print(io, err.message)
    print(io, " (line ", err.context.line, ")\n\n")
    show(io, err.context)
end

"""
    BibTeXing.fetch!([f1=f,] f, ctx) -> s

Fetch range of matching characters in context `ctx` starting at its current index. If any
matching characters are found, the context index is positioned after the last matching
character and the sub-string with the matching characters is returned. Otherwise, the
context index is left unchanged and `nothing` is returned.

Arguments `f1` and `f` are predicate functions (the first being optional) which shall return
whether a character is valid. If specified, `f1` is only used to check the first character
(that is the one at the current position in `ctx`).

"""
fetch!(f::Function, ctx::Context) = fetch!(f, f, ctx)

function fetch!(f1::Function, f::Function, ctx::Context)
    # Check first character.
    s, i, n = ctx.string, ctx.index, ctx.stop
    i > n && return nothing
    c = @inbounds s[i]
    f1(c)::Bool || return nothing
    if c == '\r' || (c == '\n' && peek_prev(s, i) != '\r')
        ctx.line += 1
    end

    # Check subsequent characters.
    i2 = i1 = i # endpoints of the sequence
    while true
        i = nextind(s, i)
        i > n && break
        p = c # previous character
        c = @inbounds s[i]
        f(c)::Bool || break
        i2 = i
        if c == '\r' || (c == '\n' && p != '\r')
            ctx.line += 1
        end
    end
    ctx.index = i
    return @inbounds SubString(s, i1, i2)
end

"""
    BibTeXing.fetch!(Int, ctx) -> val

Fetch next literal decimal number in context `ctx`. The result is an integer or `nothing`.

"""
function fetch!(::Type{T}, ctx::Context) where {T<:Integer}
    s, i, n = ctx.string, ctx.index, ctx.stop
    val = zero(T)
    base = T(10)::T
    flg = false
    while i ≤ n
        c = @inbounds s[i]
        is_digit(c) || break
        flg = true
        old = val
        val = T(c - '0')::T + val*base
        if val < old
            ctx.index = i
            throw(ParseError(ctx, "integer overflow"))
        end
        i = nextind(s, i)
    end
    if flg
        ctx.index = i
        return val
    else
        return nothing
    end
end

"""
    startswith(ctx, c::AbstractChar) -> bool
    startswith(ctx, f::Function) -> bool

Return whether current character in context `ctx` is equal to `c` (1st above case) or the
result of applying the predicate function `f` to the current character (2nd above case). In
any case, `false` is returned if context index is after the end.

A predicate function `f` can be used in-place of `c`.
"""
Base.startswith(ctx::Context, c::AbstractChar) =
    !eof(ctx) && (@inbounds ctx.string[ctx.index]) == c
Base.startswith(ctx::Context, f::Function) =
    !eof(ctx) && f(@inbounds ctx.string[ctx.index])::Bool

"""
    BibTeXing.next!(ctx) -> ctx

Advance the index of context `ctx` by one character and return the context.

"""
@inline function next!(ctx::Context)
    ctx.index = (ctx.index < ctx.stop) ? nextind(ctx.string, ctx.index) : (ctx.stop + 1)
    return ctx
end

"""
    BibTeXing.skipspaces!(ctx) -> ctx

Skip spaces in context `ctx` starting at its current position. On return, the context index
is either at a non-space character or after the end of `ctx`.

"""
skipspaces!(ctx::Context) =  skip!(is_space, ctx)

"""
    BibTeXing.skip!(f, ctx) -> ctx

Starting at current position of context `ctx`, skip characters `c` for which predicate
`f(c)` is true. On return, the context index is either at a character `c` such that `f(c)`
is false or after the end of `ctx`.

"""
function skip!(f::Function, ctx::Context)
    s, i, n = ctx.string, ctx.index, ctx.stop
    while i ≤ n
        c = @inbounds s[i]
        if !f(c)
            ctx.index = i
            break
        end
        if c == '\r' || (c == '\n' && peek_prev(s, i) != '\r')
            ctx.line += 1
        end
        i = nextind(s, i)
    end
    return ctx
end

"""
    BibTeXing.findnext!(c::AbstractChar, ctx) -> bool
    BibTeXing.findnext!(f::Function, ctx) -> bool

Skip characters until a character equal to `c` (1st above case) or for which the predicate
`f` is true (2nd above case) is encountered in context `ctx`. If a matching character is
found, the context index is positioned at this character and `true` is returned. Otherwise,
if no match is found, the context index is positioned after the end of `ctx` and `false` is
returned.

"""
findnext!(c::AbstractChar, ctx::Context) = findnext!(isequal(c), ctx)

function findnext!(f::Function, ctx::Context)
    s, i, n = ctx.string, ctx.index, ctx.stop
    while true
        if i > n
            ctx.index = i
            return false
        end
        c = @inbounds s[i]
        if c == '\r' || (c == '\n' && peek_prev(s, i) != '\r')
            ctx.line += 1
        end
        i = nextind(s, i) # index to next character
        if f(c)
            ctx.index = i
            return true
        end
    end
end

# peek_*(s, i) peek a character at, before, or after index i
# returning nothing if this character is out of bounds.
@inline peek_at(s::AbstractString, i::Int) =
    1 ≤ i ≤ ncodeunits(s) ? @inbounds(s[i]) : nullchar(s)
@inline peek_prev(s::AbstractString, i::Int) =
    peek_at(s, prevind(s, i))
@inline peek_next(s::AbstractString, i::Int) =
    peek_at(s, nextind(s, i))
