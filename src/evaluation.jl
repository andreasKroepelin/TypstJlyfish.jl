function reset_module!(js::JlyfishState)
    js.eval_module = Module(gensym("JlyfishEval"))
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

function handle_code_cell!(js::JlyfishState, code_cell::CodeCell)
    should_skip = (
        # skipping requested
        !code_cell.recompute
        # we already computed this
        && code_cell.id in keys(js.evaluations)
        # the code has not changed
        && js.evaluations[code_cell.id].code == code_cell.code
    )
    if should_skip
        @info """
            Skipping recomputation of code section with id $(code_cell.id):
            $(truncate_code(code_cell.code, 40))
        """
        throw(SkipCodeCell())
    end

    reset!(js.logger)
    computation = with_stdout_and_logger(; js.stdout_file, js.logger) do
        try
            r = Core.eval(js.eval_module, Meta.parseall(code_cell.code))
            (result = r, failed = false)
        catch e
            (result = e, failed = true)
        end
    end

    if computation.failed && computation.result isa InterruptException
        throw(StopRunning())
    end

    formatted_result = if code_cell.display || computation.failed
        find_best_representation(
            computation.result,
            code_cell.preferredmimes,
            computation.failed
        )
    else
        T = typeof(computation.result)
        if is_serialisable_type(T)
            FormattedResult(
                data = computation.result,
                failed = false,
                mime = "",
            )
        else
            FormattedResult(
                data => "Illegal type: $T",
                failed => true,
                mime => "text/plain",
            )
        end
    end

    js.evaluations[code_cell.id] = Evaluation(;
        stdout = read(js.stdout_file, String),
        result = formatted_result,
        logs = copy(js.logger.logs),
        code = code_cell.code,
    )
end

function run_evaluation!(js::JlyfishState)
    for code_cell in js.code_cells
        try
            handle_code_cell!(js, code_cell)
        catch e
            if e isa SkipCodeCell
                continue
            else
                throw(e)
            end
        end
    end
end

function execute!(js::JlyfishState)
    if !isfile(js.evaluation_file)
        write_json(js)
    end

    typst_query!(js)
    update_project(js)
    reset_module!(js)

    run_evaluation!(js)

    write_json(js)
end

function write_json(js::JlyfishState)
    out_json = JSON3.write(js.evaluations)
    write(js.evaluation_file, out_json)
    @info "Output written to file $(js.evaluation_file)"
end
