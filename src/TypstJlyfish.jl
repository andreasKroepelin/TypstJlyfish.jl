module TypstJlyfish

import Typst_jll
import JSON3
using Base64
import Pkg
import FileWatching
import Dates

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


function watch(
    typst_file;
    typst_args = "",
    evaluation_file = default_output_file(typst_file),
)
    Pkg.activate(mktempdir(prefix = "juyst-eval"))

    juyst_state = JuystState(;
        evaluation_file,
        typst_file,
        typst_args = split(typst_args),
    )

    while true
        @info Dates.format(Dates.now(), "HH:MM:SS")

        try
            execute!(juyst_state)
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

function compile(
    typst_file;
    typst_query_args = "",
    typst_compile_args = "",
    evaluation_file = default_output_file(typst_file),
)
    Pkg.activate(mktempdir(prefix = "juyst-eval"))

    juyst_state = JuystState(;
        evaluation_file,
        typst_file,
        typst_args = split(typst_query_args),
    )

    try
        execute!(juyst_state)
    catch e
        if e isa StopRunning
            return
        elseif e isa WaitForChange
        else
            throw(e)
        end
    end

    compile_cmd = ```
        $(Typst_jll.typst())
        compile
        $(split(typst_compile_args))
        $(juyst_state.typst_file)
    ```
    @info "Compiling document..."
    try
        run(compile_cmd)
    catch e
        if e isa InterruptException
        elseif e isa ProcessFailedException
            @info "Typst compile failed."
        else
            throw(e)
        end
    end

    @info "Done."
end

end
