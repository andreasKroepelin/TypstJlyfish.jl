module Juyst

import Typst_jll
import CBOR
import JSON3
import Pkg
import FileWatching
import Dates
using Dictionaries

struct SkipCodeCell end
struct StopRunning end
struct ContinueRunning end
struct WaitForChange end
const HowToProceed = Union{
    SkipCodeCell,
    StopRunning,
    ContinueRunning,
    WaitForChange,
}

include("output.jl")
include("logging.jl")
include("state.jl")
include("pkg.jl")
include("query.jl")
include("evaluation.jl")


function run(
    typst_file;
    typst_args = "",
    evaluation_file = default_cbor_file(typst_file),
)
    Pkg.activate(mktempdir(prefix = "juyst-eval"))

    how_to_proceed::HowToProceed = ContinueRunning()

    juyst_state = JuystState(;
        evaluation_file,
        typst_file,
        typst_args = split(typst_args),
    )

    while true
        @info Dates.format(Dates.now(), "HH:MM:SS")

        if !isfile(evaluation_file)
            write_cbor(juyst_state)
        end

        try
            typst_query!(juyst_state)
            update_project(juyst_state)
            reset_module!(juyst_state)

            run_evaluation!(juyst_state)

            write_cbor(juyst_state)
        catch e
            if e isa StopRunning
                break
            elseif e isa WaitForChange
            else
                throw(e)
            end
        end

        @info "Waiting for input to change..."
        try
            FileWatching.watch_file(typst_file)
        catch e
            if e isa InterruptException
                break
            else
                throw(e)
            end
        end
    end

    @info "Stopping Juyst. Bye!"
end

end
