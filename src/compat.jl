# Backward compatibility.

@static if !isdefined(Base, :Memory)
    const Memory{T} = Vector{T}
end

@static if !isdefined(Base, :isnothing)
    isnothing(::Nothing) = true
    isnothing(::Any) = false
end
