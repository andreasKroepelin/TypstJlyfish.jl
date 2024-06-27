function typst_query!(js::JuystState)::HowToProceed
    query_cmd = ```
        $(Typst_jll.typst())
        query
        $(js.typst_args)
        $(js.typst_file)
        --field value
        "<juyst-data>"`
    ```

    raw_query_str = try
        JSON3.read(read(query_cmd, String))
    catch e
        if e isa InterruptException
            return StopRunning()
        end
        if e isa ProcessFailedException
            @info "Typst query failed."
            return ContinueRunning()
        end
        throw(e)
    end

    if js.previous_query_str == raw_query_str
        @info "Typst file changed but Julia code is identical to previous version."
        return ContinueRunning()
    end
    js.previous_query_str = raw_query_str

    raw_query_object = JSON3.read(raw_query_str)
    @assert raw_query_output isa AbstractVector

    js.prev_pkg = js.pkg
    js.pkg = PkgState()
    js.code_cells = CodeCell[]

    for query_item in raw_query_object
        if all(f -> haskey(qi, f), fieldnames(CodeCell))
            code_cell = CodeCell(; (f => qi[f] for f in fieldnames(CodeCell))...)
            push!(js.code_cells, code_cell)
        else if haskey(qi, :pkgs) && haskey(qi, :cmd)
            if qi.pkgs isa AbstractVector && qi.cmd isa AbstractString
                pkgs = Pkg.REPLMode.parse_package(
                    Pkg.REPLMode.QString.(pkgs, false)
                )
                if qi.cmd == "add"
                    append!(js.pkg.add_pkgs, pkgs)
                else if qi.cmd == "dev"
                    append!(js.pkg.dev_pkgs, pkgs)
                end
            end
        end
    end
end
