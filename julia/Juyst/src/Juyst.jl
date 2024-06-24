module Juyst

import Typst_jll
import CBOR
import JSON
import Pkg
import FileWatching
import Dates

function find_best_representation(result, preferred_mimes, failed)
    mimes = MIME.([
        "text/typst",
        "image/svg+xml",
        "image/png",
        "image/jpg",
        "text/plain",
    ])
    preference(m) = something(
        findfirst(==(string(m)), preferred_mimes),
        length(preferred_mimes) + 1
    )
    sort!(mimes, by = preference)

    for mime in mimes
        (@invokelatest showable(mime, result)) || continue

        iob = IOBuffer()
        @invokelatest show(iob, mime, result)
        bytes = take!(iob)
        return Dict(
            "mime" => string(mime),
            "data" => startswith(string(mime), "text/") ? String(bytes) : bytes,
            "failed" => failed,
        )
    end

    # no MIME worked
    Dict(
        "mime" => "text/plain",
        "data" => "!! Result could not be displayed !!",
        "failed" => true
    )
    
end

function is_allowed_type(T)
    valtype(::Type{Dict{String, V}}) where V = V
    primitives = [
        String, Integer, Bool, Char, Float64, Float32, Nothing
    ]
    if any(T .<: primitives)
        return true
    elseif T <: Vector
        return is_allowed_type(eltype(T))
    elseif T <: Dict{String}
        return is_allowed_type(valtype(T))
    else
        return false
    end
end

function truncate_code(code, n)
    chars = Vector{Char}(code)
    if length(chars) <= n
        code
    else
        join(chars[1:n - 3]) * "..."
    end
end

import Logging

struct TypstLogger <: Logging.AbstractLogger
    logs::Vector

    TypstLogger() = new([])
end

reset!(logger::TypstLogger) = empty!(logger.logs)

function Logging.handle_message(logger::TypstLogger, level, message, _module, group, id, file, line; kwargs...)
    processed_kwargs = Dict(
        string(kwarg.first) => find_best_representation(kwarg.second, [], false)
        for kwarg in kwargs
    )
    push!(
        logger.logs,
        Dict("level" => level.level, "message" => message, "attached" => processed_kwargs)
    )
end

Logging.shouldlog(::TypstLogger, level, _module, group, id) = level >= Logging.Info
Logging.min_enabled_level(::TypstLogger) = Logging.Info

function default_cbor_file(typst_file)
    @assert endswith(typst_file, ".typ") "given Typst file does not end with .typ"
    base, _suffix = splitext(typst_file)
    base * "-juyst.cbor"
end

function run(
    typst_file;
    typst_args = "",
    evaluation_file = default_cbor_file(typst_file),
)
    query_cmds = (
        code = `$(Typst_jll.typst()) query $(split(typst_args)) $typst_file --field value "<juyst-julia-code>"`,
        pkg = `$(Typst_jll.typst()) query $(split(typst_args)) $typst_file --field value "<juyst-pkg>"`,
    )
    stdout_file = tempname()
    project_dir = mktempdir(prefix = "juyst-eval")
    Pkg.activate(project_dir)
    previous_query_strs = (code = "", pkg = "")
    previous_pkg_specs = Pkg.PackageSpec[]
    running = true
    logger = TypstLogger()
    if isfile(evaluation_file)
        evaluations = CBOR.decode(read(evaluation_file))
    else
        evaluations = Dict{String, Any}()
    end

    while running
        @info Dates.format(Dates.now(), "HH:MM:SS")
        if !isfile(evaluation_file)
            write(evaluation_file, CBOR.encode(evaluations))
        end

        query_strs = try
            map(query_cmds) do query_cmd
                read(query_cmd, String)
            end
        catch e
            if e isa InterruptException
                running = false
                break
            end
            if e isa ProcessFailedException
                @info "Typst query failed." query_cmd
                FileWatching.watch_file(typst_file)
                continue
            end
            throw(e)
        end

        if query_strs == previous_query_strs
            @info "Typst file changed but Julia code is identical to previous version."
            FileWatching.watch_file(typst_file)
            continue
        end
        previous_query_strs = query_strs
        query = map(JSON.parse, query_strs)

        eval_module = Module(:JuystEval)

        pkgs = reduce(vcat, query.pkg)
        qstrs = Pkg.REPLMode.QString.(pkgs, false)
        pkg_specs = Pkg.REPLMode.parse_package(qstrs, nothing)
        # `setdiff` would be more straight forward but it somehow behaves
        # strangely here...
        pkg_to_add = [p for p in pkg_specs if !(p in previous_pkg_specs)]
        pkg_to_rm  = [p for p in previous_pkg_specs if !(p in pkg_specs)]
        isempty(pkg_to_add) || Pkg.add(pkg_to_add)
        isempty(pkg_to_rm)  || Pkg.rm(pkg_to_rm)
        previous_pkg_specs = pkg_specs

        for value in query.code
            should_skip = (
                # skipping requested
                !value["recompute"]
                # we already computed this
                && value["id"] in keys(evaluations)
                # the code has not changed
                && evaluations[value["id"]]["code"] == value["code"]
            )
            if should_skip
                @info """
                    Skipping recomputation of code section with id $(value["id"]):
                    $(truncate_code(value["code"], 40))
                """
                continue
            end
            computation = open(stdout_file, "w") do my_stdout
                redirect_stdout(my_stdout) do
                    Logging.with_logger(logger) do
                        try
                            r = Core.eval(eval_module, Meta.parseall(value["code"]))
                            (result = r, failed = false)
                        catch e
                            if e isa InterruptException
                                running = false
                            end
                            (result = e, failed = true)
                        end
                    end
                end
            end
            formatted_result = if value["display"] || computation.failed
                find_best_representation(
                    computation.result,
                    value["preferred-mimes"],
                    computation.failed
                )
            else
                if is_allowed_type(typeof(result))
                    Dict(
                        "data" => result,
                        "failed" => failed,
                        "mime" => "",
                    )
                else
                    Dict(
                        "data" => "Illegal type: $(typeof(result))",
                        "failed" => true,
                        "mime" => "",
                    )
                end
            end
            evaluation = Dict(
                "stdout" => read(stdout_file, String),
                "result" => formatted_result,
                "logs" => copy(logger.logs),
                "code" => value["code"],
            )
            evaluations[value["id"]] = evaluation
            reset!(logger)
        end
        out_cbor = CBOR.encode(evaluations)
        write(evaluation_file, out_cbor)
        @info "Output written to file." evaluation_file
        FileWatching.watch_file(typst_file)
    end
end

end
