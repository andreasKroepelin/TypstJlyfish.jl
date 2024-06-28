#import "../../../typst/lib.typ": *

#jl-pkg("Example", "Random")
// #jl-pkg(cmd: "add", "LinearAlgebra")

#jl(`1 + 1 `)

#jl-raw(fn: x => [#{x + 3}], `1 + 2`)

#jl(```julia
  @info "hi"
  println("wow")
```)
