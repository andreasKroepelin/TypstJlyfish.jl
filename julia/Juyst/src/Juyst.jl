module Juyst

import Typst_jll
import CBOR
import JSON3
import Pkg
import FileWatching
import Dates

struct StopRunning end
struct ContinueRunning end
const HowToProceed = Union{StopRunning, ContinueRunning}

macro short_circuit(e)
    quote
        if $(esc(e)) isa StopRunning
            hot_to_proceed = StopRunning()
            break
        end
    end
end


include("output.jl")
include("logging.jl")
include("state.jl")
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
        split(typst_args),
    )

    while how_to_proceed isa ContinueRunning
        @info Dates.format(Dates.now(), "HH:MM:SS")

        if !isfile(evaluation_file)
            write_cbor(evaluation_state)
        end

        @short_circuit typst_query!(juyst_state)
        update_project(juyst_state)
        reset_module!(evaluation_state)

        for code_cells in code_cells
            @short_circuit handle_code_cell!(evaluation_state, code_cell)
        end

        write_cbor(evaluation_state)

        try
            FileWatching.watch_file(typst_file)
        catch e
            if e isa InterruptException
                @short_circuit StopRunning()
            end
        end
    end

    @info "Stopping Juyst. Bye!"
end

end
