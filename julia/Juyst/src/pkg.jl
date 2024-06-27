function add_and_rm(pkgs_new, pkgs_old)
    # `setdiff` would be more straight forward but it somehow behaves strangely
    # here...
    pkg_to_add = filter(!in(pkgs_old), pkgs_new)
    pkg_to_rm  = filter(!in(pkgs_new), pkgs_old)
    isempty(pkg_to_add) || Pkg.add(pkg_to_add)
    isempty(pkg_to_rm)  || Pkg.rm(pkg_to_rm)
end

function update_project!(js::JuystState)
    (; pkg, prev_pkg) = js
    add_and_rm(pkg.add_pkgs, prev_pkgs.add_pkgs)
    add_and_rm(pkg.dev_pkgs, prev_pkgs.dev_pkgs)
end
