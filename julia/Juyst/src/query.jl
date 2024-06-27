struct PkgCommand
    cmd::String
    pkgs::Vector{String}
end

struct PkgAddCommand
    pkgs::Vector{String}
end

struct PkgDevCommand
    pkgs::Vector{String}
end

struct CodeCell
    code::String
    id::String
    display::Bool
    recompute::Bool
    preferred_mimes::Vector{MIME}
end

function typst_query(typst_file, typst_args)
    query_cmd = ```
        $(Typst_jll.typst())
        query
        $(split(typst_args))
        $typst_file
        --field value
        "<juyst-data>"`
    ```
end
