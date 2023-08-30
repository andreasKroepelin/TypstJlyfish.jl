#let julia-code-counter = counter("julia-code")
#let julia-output = json("julia-evaluated.json")

#let code-evaluated(code, evaluated) = {
  let radius = .5em
  let inset = 5pt
  let evaluated-body = if evaluated != none {
    let result = evaluated.result
    let output = evaluated.output
    let logs = evaluated.logs
    let mime = result.mime
    let data = result.data
    let neither = true
    if not (mime == "text/plain" and data in ("", "nothing")) {
      block(
        width: 100%,
        inset: inset,
        stroke: (top: (paint: eastern, thickness: 1pt, dash: "dashed")),
        {
          if result.failed {
            block(inset: inset, fill: red, text(fill: white, style: "italic")[error])
          }
          set text(fill: red, weight: "bold") if result.failed
          if mime == "text/plain" {
            raw(block: true, data)
          } else if mime.starts-with("image/") {
            align(center, image(data, width: 50%))
          } else {
            panic("Unsupported MIME type: " + mime)
          }
          place(top + right, text(size: .5em, fill: luma(100), raw(mime)))
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
    if logs.len() > 0 {
      let level-symbol(it) = align(center + horizon, text(fill: white, it))
      block(
        width: 100%,
        inset: inset,
        stroke: (top: (paint: eastern, thickness: 1pt, dash: "dashed")),
        grid(columns: (auto, 1fr), column-gutter: 1em, row-gutter: .5em,
          ..logs.map(log => (
            if log.level >= 0 and log.level < 1000 {
              circle(radius: .7em, fill: aqua, stroke: none, level-symbol[i])
            } else if log.level >= 1000 and log.level < 2000 {
              square(size: 1.4em, fill: orange, stroke: none, level-symbol[w])
            } else if log.level >= 2000 {
              square(size: 1.4em, fill: red, stroke: none, level-symbol[e])
            },
            align(horizon, text(size: .8em, eval(log.message, mode: "markup")))
          )).flatten()
        )
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
      text(fill: luma(100))[_not evaluated_]
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
        text(fill: white, weight: "bold")[julia]
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

#let julia-eval(it, preferred-mimes: ()) = {
  let preferred-mimes = if type(preferred-mimes) == "array" {
    preferred-mimes
  } else {
    (preferred-mimes, )
  }
  julia-code-counter.display(id => {
    [ #metadata((preferred-mimes: preferred-mimes, code: it.text)) <julia-code> ]

    code-evaluated(it, julia-output.at(id, default: none))
  })


  julia-code-counter.step()
}

#set text(font: "Atkinson Hyperlegible")
#show raw: set text(font: "JuliaMono")
#set par(justify: true)

= Evaluating Julia code in Typst

You can now evaluate the code in Julia code blocks in your Typst document!
Look here:
#julia-eval(```julia
x = 3
y = 4
x * y
```)
It's as simple as wrapping your code block in the `#julia-eval` function.
The evaluation script will *automatically reevaluate your code* when necessary
(kind of like `typst watch`).
````typ
#julia-eval(```julia
x = 3
y = 4
x * y
```)
````

Code is evaluated in a separate environment and in its own module.
We can therefore without worrying write:
#julia-eval(```julia
import Pkg
Pkg.add(["ImageShow", "TestImages", "Plots"])
using ImageShow, TestImages, Plots
```
)

All evaluated code-blocks share one scope.
Remember the `x` from before?
It is still valid:
#julia-eval(```julia
sin(x * pi)
```)

To prevent variables from being in the global scope, you can use a `let` block,
for example:
#julia-eval(```julia
let
    z = 2
end
```)

Now `z` does not exist outside of that code block:
#julia-eval(```julia
z
```)

There are four types of things that can appear below your code block.
So far, we have seen the output of the code, as one would expect.
#footnote[
  In the top right corner, you can see the MIME type of the output.
  Currently `image/svg+xml`, `image/png`, `image/jpg` and `text/plain` are
  supported.
  In that order, they are considered to be used to display the output.
  You can also specify that you prefer certain ones in your Typst code.
]
But there are also two different types:
If you print something to `stdout`, it appears in its own section, as well as
if you use Julia's logging framework using the macros `@info`, `@warn` or `@error`.
Log messages are interpreted as Typst content.

#julia-eval(```julia
a = 2.718
println("Let's print something!")
println("log($a) = $(log(a))")
@info "This is an *info*, telling you that \$1 + 1 = 2\$."
@warn "This is a ... #h(3em) wait for it ... #h(3em) warning!"
@error "This is an _error_."
# and let's also return a result
1 / a
```)

Earlier, we loaded the `Plots` package, let's use it:
#julia-eval(```julia
plot(-2pi:.01:2pi, cos)
```
)

And finally, let's all remember our lovely home planet.
#julia-eval(preferred-mimes: "image/png",```julia
testimage("earth_apollo17.jpg")
```
)
