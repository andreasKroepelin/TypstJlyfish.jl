function typst_query!(js::JuystState)
    query_cmd = ```
        $(Typst_jll.typst())
        query
        $(js.typst_args)
        $(js.typst_file)
        --field value
        "<juyst-data>"
    ```

    raw_query_str = try
        read(query_cmd, String)
    catch e
        if e isa InterruptException
            throw(StopRunning())
        end
        if e isa ProcessFailedException
            @info "Typst query failed."
            throw(WaitForChange())
        end
        throw(e)
    end

    if js.previous_query_str == raw_query_str
        @info "Typst file changed but Julia code is identical to previous version."
        throw(WaitForChange())
    end
    js.previous_query_str = raw_query_str

    raw_query_object = JSON3.read(raw_query_str)
    @assert raw_query_object isa AbstractVector

    js.prev_pkg = js.pkg
    js.pkg = PkgState()
    js.code_cells = CodeCell[]

    for qi in raw_query_object
        if all(f -> haskey(qi, f), fieldnames(CodeCell))
            code_cell = CodeCell(; (f => qi[f] for f in fieldnames(CodeCell))...)
            push!(js.code_cells, code_cell)
        elseif haskey(qi, :pkgs) && haskey(qi, :cmd)
            if qi.pkgs isa AbstractVector && qi.cmd isa AbstractString
                pkgs = Pkg.REPLMode.parse_package(
                    Pkg.REPLMode.QString.(qi.pkgs, false),
                    nothing
                )
                if qi.cmd == "add"
                    append!(js.pkg.add_pkgs, pkgs)
                elseif qi.cmd == "dev"
                    append!(js.pkg.dev_pkgs, pkgs)
                end
            end
        end
    end
end
