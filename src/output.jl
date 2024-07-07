@kwdef struct FormattedResult
    mime::String
    failed::Bool
    data::Any
end


function find_best_representation(result, preferred_mimes, failed)
    if failed && result isa Exception
        iob = IOBuffer()
        @invokelatest showerror(iob, result)

        data = String(take!(iob))
        return FormattedResult(; mime = "text/plain", data, failed)
    end
    mimes = [
        "text/typst",
        "image/svg+xml",
        "image/png",
        "image/jpg",
        "text/plain",
    ]
    preference(m) = something(
        findfirst(==(m), preferred_mimes),
        length(preferred_mimes) + 1
    )
    sort!(mimes, by = preference)

    for mime in mimes
        mime = MIME(mime)
        (@invokelatest showable(mime, result)) || continue

        iob = IOBuffer()
        @invokelatest show(iob, mime, result)
        bytes = take!(iob)
        data = if istextmime(mime)
            String(bytes)
        else
            base64encode(bytes)
        end
        return FormattedResult(; mime = string(mime), data, failed)
    end

    # no MIME worked
    FormattedResult(
        mime = "text/plain",
        data = "!! Result could not be displayed !!",
        failed = true
    )
    
end

function is_serialisable_type(T)
    valtype(::Type{Dict{String, V}}) where V = V
    primitives = [
        String, Integer, Bool, Char, Float64, Float32, Nothing
    ]
    if any(T .<: primitives)
        return true
    elseif T <: Vector
        return is_serialisable_type(eltype(T))
    elseif T <: Dict{String}
        return is_serialisable_type(valtype(T))
    else
        return false
    end
end

function truncate_code(code, n)
    chars = Vector{Char}(replace(strip(code), "\n" => " "))
    if length(chars) <= n
        code
    else
        join(chars[1:n - 3]) * "..."
    end
end


function default_output_file(typst_file)
    @assert endswith(typst_file, ".typ") "given Typst file does not end with .typ"
    base, _suffix = splitext(typst_file)
    base * "-jlyfish.json"
end

