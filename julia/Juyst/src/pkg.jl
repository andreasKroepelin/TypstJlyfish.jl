function if_not_empty(f, pkgs)
    if !isempty(pkgs)
        f(collect(pkgs))
    end
end

function update_project(js::JuystState)
    (; pkg, prev_pkg) = js
    if pkg != prev_pkg
        currently_installed = [
            Pkg.PackageSpec(name, uuid)
            for (name, uuid)
            in Pkg.project().dependencies |> pairs
        ]
        if_not_empty(Pkg.rm, currently_installed)
        try
            if_not_empty(Pkg.add, pkg.add_pkgs)
            if_not_empty(Pkg.develop, pkg.dev_pkgs)
        catch e
            message = string(e)
            @error "Updating package dependencies failed!" message
            throw(WaitForChange())
        end
    end
end
