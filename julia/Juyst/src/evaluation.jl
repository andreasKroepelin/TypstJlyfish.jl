function reset_module!(js::JuystState)
    js.module = Module(gensym("JuystEval"))
end


function with_stdout_and_logger(
    f;
    stdout_file::AbstractString,
    logger::Logging.AbstractLogger
)
    open(stdout_file, "w") do my_stdout
        redirect_stdout(my_stdout) do
            Logging.with_logger(logger) do
                f()
            end
        end
    end
end

function handle_code_cell!(js::JuystState, code_cell::CodeCell)::HowToProceed
    should_skip = (
        # skipping requested
        !code_cell.recompute
        # we already computed this
        && code_cell.id in keys(js.evaluations)
        # the code has not changed
        && evaluations[code_cell.id].code == code_cell.code
    )
    if should_skip
        @info """
            Skipping recomputation of code section with id $(code_cell.id):
            $(truncate_code(code_cell.code, 40))
        """
        return ContinueRunning()
    end

    js.reset!(logger)
    computation = with_stdout_and_logger(; js.stdout_file, js.logger) do
        try
            r = Core.eval(js.eval_module, Meta.parseall(code_cell.code))
            (result = r, failed = false)
        catch e
            (result = e, failed = true)
        end
    end

    if computation.failed && computation.result isa InterruptException
        return StopRunning()
    end

    formatted_result = if code_cell.display || computation.failed
        find_best_representation(
            computation.result,
            code_cell.preferredmimes,
            computation.failed
        )
    else
        T = typeof(computation.result)
        if is_allowed_type(T)
            FormattedResult(
                data = computation.result,
                failed = false,
                mime = MIME""(),
            )
        else
            FormattedResult(
                data => "Illegal type: $T",
                failed => true,
                mime => MIME"text/plain",
            )
        end
    end

    js.evaluations[code_cell.id] = Evaluation(;
        stdout = read(stdout_file, String),
        result = formatted_result,
        logs = copy(logger.logs),
        code = value["code"],
    )

    ContinueRunning()
end

function write_cbor(js::JuystState)
    out_cbor = CBOR.encode(js.evaluations)
    write(js.evaluation_file, out_cbor)
    @info "Output written to file $(js.evaluation_file)"
end