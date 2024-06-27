struct PkgState
    add_pkgs::Vector{Pkg.PackageSpec}
    dev_pkgs::Vector{Pkg.PackageSpec}

    PkgState() = new(
        Pkg.PackageSpec[],
        Pkg.PackageSpec[],
    )
end

@kwdef struct Evaluation
    result::FormattedResult
    stdout::String
    logs::Vector{Log}
    code::String
end

mutable struct EvaluationState
    pkg::PackageState
    stdout_file::String
    logger::TypstLogger
    eval_module::Module
    evaluation_file::String
    evaluations::Dict{String, Evaluation}

    function EvaluationState(evaluation_file::String)
        if isfile(evaluation_file)
            evaluations = CBOR.decode(read(evaluation_file))
        else
            evaluations = Dict{String, Evaluation}()
        end

        new(
            PkgState(),
            tempname(),
            TypstLogger(),
            Module(gensym("JuystEval")),
            evaluation_file,
            evaluations,
        )
    end
end

function reset_module!(evs::EvaluationState)
    evs.module = Module(gensym("JuystEval"))
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

struct StopRunning end
struct ContinueRunning end
const HowToProceed = Union{StopRunning, ContinueRunning}

function handle_cell!(evs::EvaluationState, code_cell::CodeCell)::HowToProceed
    should_skip = (
        # skipping requested
        !code_cell.recompute
        # we already computed this
        && code_cell.id in keys(evs.evaluations)
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

    evs.reset!(logger)
    computation = with_stdout_and_logger(; evs.stdout_file, evs.logger) do
        try
            r = Core.eval(evs.eval_module, Meta.parseall(code_cell.code))
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
            code_cell.preferred_mimes,
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

    evaluation = Evaluation(;
        stdout = read(stdout_file, String),
        result = formatted_result,
        logs = copy(logger.logs),
        code = value["code"],
    )
    evs.evaluations[code_cell.id] = evaluation

    ContinueRunning()
end

function write_cbor(evs::EvaluationState)
    out_cbor = CBOR.encode(evs.evaluations)
    write(evs.evaluation_file, out_cbor)
    @info "Output written to file $(evs.evaluation_file)"
end
