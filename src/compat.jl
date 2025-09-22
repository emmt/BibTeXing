# Backward compatibility.

@static if !isdefined(Base, :Memory)
    const Memory{T} = Vector{T}
end

@static if !isdefined(Base, :isnothing)
    isnothing(::Nothing) = true
    isnothing(::Any) = false
end

"""
    BibTeXing.@public args...

Declare `args...` as being `public` even though they are not exported. For Julia version <
1.11, this macro does nothing. Using this macro also avoid errors with CI and coverage
tools.

"""
macro public(args::Union{Symbol,Expr}...)
    VERSION ≥ v"1.11.0-DEV.469" ? esc(Expr(:public, map(
        x -> x isa Symbol ? x :
            x isa Expr && x.head == :macrocall ? x.args[1] :
            error("unexpected argument `$x` to `@public`"), args)...)) : nothing
end
VERSION ≥ v"1.11.0-DEV.469" && @public @public
