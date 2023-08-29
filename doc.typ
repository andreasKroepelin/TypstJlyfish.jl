#let evaluated-julia-code(
  evaluation-file: "julia-evaluated.json",
  body
) = {

  let julia-code-counter = counter("julia-code")
  let julia-output = json(evaluation-file)

  let code-evaluated(code, evaluated) = {
    let radius = .5em
    let inset = 5pt
    let evaluated-body = if evaluated != none {
      let result = evaluated.result
      let output = evaluated.output
      let mime = result.mime
      let data = result.data
      let neither = true
      if not (mime == "text/plain" and data in ("", "nothing")) {
        block(
          width: 100%,
          inset: inset,
          stroke: (top: (paint: eastern, thickness: 1pt, dash: "dashed")),
          if mime == "text/plain" {
            raw(block: true, data)
          } else if mime.starts-with("image/") {
            align(center, image(data, width: 50%))

            [#mime]
          } else {
            panic("Unsupported MIME type: " + mime)
          }
        )
        neither = false
      }
      if output != "" {
        block(
          width: 100%,
          inset: inset,
          stroke: (top: (paint: eastern, thickness: 1pt, dash: "dashed")),
          {
            block(
              stroke: 1pt + eastern,
              inset: inset,
              // radius: (top-left: radius, bottom-right: radius),
              text(fill: eastern, style: "italic")[`stdout`]
            )
            raw(block: true, output)
          }
        )
        neither = false
      }
      if neither {
        v(inset)
      }
    } else {
      block(
        width: 100%,
        inset: inset,
        text(font: "Atkinson Hyperlegible", fill: luma(100))[_not evaluated_]
      )
    }
  
    block(
      width: auto,
      breakable: false,
      stroke: 1pt + eastern,
      radius: radius,
      {
        block(
          fill: eastern,
          inset: inset,
          radius: (top-left: radius, bottom-right: radius),
          text(font: "Atkinson Hyperlegible", fill: white, weight: "bold")[julia]
        )
        block(
          width: 100%,
          inset: (x: inset),
          code
        )
        evaluated-body
      }
    )
  }

  show raw.where(block: true, lang: "julia"): it => {
    julia-code-counter.display(id => {
      [ #metadata((id: id, code: it.text)) <julia-code> ]

      code-evaluated(it, julia-output.at(id, default: none))
    })

  
    julia-code-counter.step()
  }

  body
}

#set text(font: "Atkinson Hyperlegible")
#show raw: set text(font: "JuliaMono")

#show: evaluated-julia-code

Let us set up an environment:
```julia
import Pkg
Pkg.add("TestImages")
Pkg.add("Plots")
Pkg.add("ImageShow")
using TestImages
using ImageShow
using Plots
```

Here is a piece of Julia code:
```julia
using LinearAlgebra
D = Diagonal(1:4)
x = 3:6
D * x
```

And here is some more:
```julia
plot(0:.01:2pi, cos)

```

```julia
testimage("coffee.png")
```
