using JSON
import Pkg
import FileWatching

function find_best_representation(result, output_dir, preferred_mimes, failed)
    mimes = MIME.(["image/svg+xml", "image/png", "image/jpg", "text/plain"])
    preference(m) = something(
        findfirst(==(string(m)), preferred_mimes),
        length(preferred_mimes) + 1
    )
    # @info "preferred mimes" preferred_mimes
    # @info "preferences" preference.(mimes)
    sort!(mimes, by = preference)
    # @info "new mime order" mimes

    function to_output(mime::MIME"text/plain", x)
        str = let iob = IOBuffer()
            @invokelatest show(iob, mime, x)
            String(take!(iob))
        end
        (mime = "text/plain", data = str, failed)
    end
    
    suffix(::MIME"image/svg+xml") = ".svg"
    suffix(::MIME"image/jpg") = ".jpg"
    suffix(::MIME"image/png") = ".png"

    function to_output(mime::Union{MIME"image/svg+xml", MIME"image/png", MIME"image/jpg"}, x)
        file = tempname(output_dir) * suffix(mime)
        open(file, "w") do io
            @invokelatest show(io, mime, x)
        end
        (mime = string(mime), data = file, failed)
    end

    for mime in mimes
        showable(mime, result) || continue
        return to_output(mime, result)
    end

    # no MIME worked
    (mime = "text/plain", data = "!! Result could not be displayed !!", failed = true)
    
end

import Logging

struct TypstLogger <: Logging.AbstractLogger
    logs::Vector
    output_dir::String

    TypstLogger(output_dir) = new([], output_dir)
end

reset!(logger::TypstLogger) = empty!(logger.logs)

function Logging.handle_message(logger::TypstLogger, level, message, _module, group, id, file, line; kwargs...)
    processed_kwargs = [
        kwarg.first => find_best_representation(kwarg.second, logger.output_dir, [], false)
        for kwarg in kwargs
    ]
    push!(
        logger.logs,
        (; level = level.level, message, attached = processed_kwargs)
    )
end

Logging.shouldlog(::TypstLogger, level, _module, group, id) = level >= Logging.Info
Logging.min_enabled_level(::TypstLogger) = Logging.Info

function run(
    typst_file;
    evaluation_file = "julia-evaluated.json",
    output_dir = "julia-evaluated-files"
)
    query_cmd = `typst query $typst_file --field value "<julia-code>"`
    stdout_file = tempname()
    previous_query_str = ""
    running = true
    logger = TypstLogger(output_dir)

    while running
        if !isfile(evaluation_file)
            write(evaluation_file, JSON.json([]))
        end
        if !isdir(output_dir)
            mkpath(output_dir)
        end

        query_str = try
            read(query_cmd, String)
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
        if query_str == previous_query_str
            @info "Typst file changed but Julia code is identical to previous version."
            FileWatching.watch_file(typst_file)
            continue
        end
        previous_query_str = query_str
        query = JSON.parse(query_str)

        Pkg.activate(; temp = true)
        eval_module = Module()
        evaluations = []
        for value in query
            result, failed = open(stdout_file, "w") do my_stdout
                redirect_stdout(my_stdout) do
                    Logging.with_logger(logger) do
                        try
                            r = Core.eval(eval_module, Meta.parseall(value["code"]))
                            r, false
                        catch e
                            if e isa InterruptException
                                running = false
                            end
                            e, true 
                        end
                    end
                end
            end
            evaluation = (
                output = read(stdout_file, String),
                result = find_best_representation(result, output_dir, value["preferred-mimes"], failed),
                logs = copy(logger.logs),
            )
            push!(evaluations, evaluation)
            reset!(logger)
        end
        Pkg.activate(".")
        out_json = JSON.json(evaluations)
        write(evaluation_file, out_json)
        @info "Output written to file." evaluation_file
        FileWatching.watch_file(typst_file)
    end
end
