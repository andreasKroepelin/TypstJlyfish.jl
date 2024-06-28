function add_and_rm(pkgs_new, pkgs_old, f)
    # `setdiff` would be more straight forward but it somehow behaves strangely
    # here...
    pkg_to_add = filter(!in(pkgs_old), pkgs_new)
    pkg_to_rm  = filter(!in(pkgs_new), pkgs_old)
    isempty(pkg_to_add) || f(pkg_to_add)
    isempty(pkg_to_rm)  || Pkg.rm(pkg_to_rm)
end

function update_project(js::JuystState)
    (; pkg, prev_pkg) = js
    try
        add_and_rm(pkg.add_pkgs, prev_pkg.add_pkgs, Pkg.add)
        add_and_rm(pkg.dev_pkgs, prev_pkg.dev_pkgs, Pkg.develop)
    catch e
        message = string(e)
        @error "Updating package dependencies failed!" message
        throw(WaitForChange())
    end
end
