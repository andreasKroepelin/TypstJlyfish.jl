#set page(width: auto, height: auto, margin: 1em)
#import "../typst/lib.typ": *

#read-julia-output(cbor("simple-juyst.cbor"))

Hello from Typst!

#jl(```julia
  greeting = rand(["Hello", "Hi", "Good morning"])
  "$greeting, this is Julia in Typst via Juyst!"
```)
