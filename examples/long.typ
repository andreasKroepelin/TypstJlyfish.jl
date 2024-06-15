#import "../typst/lib.typ": *

#read-julia-output(cbor("long-juyst.cbor"))

#jl(recompute: false, ```julia
  seconds = @elapsed sleep(10)
  @show seconds
  "Wow, this took $(round(Int, seconds)) seconds!"
```)

#jl(`"This is so fast!"`)
