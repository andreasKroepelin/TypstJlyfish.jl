#import "../typst/lib.typ": *

#set page(width: auto, height: auto, margin: 1em)

#read-julia-output(json("demo-juyst.json"))
#jl-pkg("Typstry", "Makie", "CairoMakie")

Hello from Typst!

#jl(```julia
  using Typstry 

  italics = rand(Bool)
  if italics
    typst"Hello from _Julia_!"
  else
    typst"Hello from *Julia*!"
  end
```)

#set image(width: 10em)
#jl(```
  using Makie, CairoMakie

  as = -2.2:.01:.7
  bs = -1.5:.01:1.5
  C = [a + b * im for a in as, b in bs]
  function mandelbrot(c)
    z = c
    i = 1
    while i < 100 && abs2(z) < 4
      z = z^2 + c
      i += 1
    end
    i
  end

  heatmap(as, bs, mandelbrot.(C))
```)



