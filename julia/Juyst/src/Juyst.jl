module Juyst

import Typst_jll
import CBOR
import JSON
import Pkg
import FileWatching
import Dates

include("query.jl")
include("logging.jl")
include("output.jl")
include("evaluation.jl")


function run(
    typst_file;
    typst_args = "",
    evaluation_file = default_cbor_file(typst_file),
)
    project_dir = mktempdir(prefix = "juyst-eval")
    Pkg.activate(project_dir)

    previous_query_strs = (code = "", pkg = "")
    how_to_proceed::HowToProceed = ContinueRunning()

    evaluation_state = EvaluationState(evaluation_file)

    while how_to_proceed isa ContinueRunning()
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
                @info "Typst query failed."
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

        reset_module!(evaluation_state)

        pkgs = reduce(vcat, query.pkg, init = String[])
        qstrs = Pkg.REPLMode.QString.(pkgs, false)
        pkg_specs = Pkg.REPLMode.parse_package(qstrs, nothing)
        # `setdiff` would be more straight forward but it somehow behaves
        # strangely here...
        pkg_to_add = [p for p in pkg_specs if !(p in previous_pkg_specs)]
        pkg_to_rm  = [p for p in previous_pkg_specs if !(p in pkg_specs)]
        isempty(pkg_to_add) || Pkg.add(pkg_to_add)
        isempty(pkg_to_rm)  || Pkg.rm(pkg_to_rm)
        previous_pkg_specs = pkg_specs

        for code_cells in code_cells
            handle_code_cell!(evaluation_state, code_cell)
        end
        write_cbor(evaluation_state)
        FileWatching.watch_file(typst_file)
    end
end

end
