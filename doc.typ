#import "lib.typ": *

#let julia-eval = setup-julia-eval()

#set text(font: "Atkinson Hyperlegible")
#show raw: set text(font: "JuliaMono")
#set par(justify: true)
#show raw.where(block: true, lang: "julia"): set block(
  fill: luma(240),
  inset: 5pt,
  radius: 5pt,
  width: 100%,
)

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
#julia-eval(show-anything: false, ```julia
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
#julia-eval(show-result: false, ```julia
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
@error "This is an _error_ with attached data." cos(a)
# and let's also return a result
1 / a
```)

Earlier, we loaded the `Plots` package, let's use it:
#julia-eval(```julia
plot(-2pi:.01:2pi, cos)
```
)

And finally, let's all remember our lovely home planet.
#julia-eval(preferred-mimes: "image/png", show-logs: false, ```julia
testimage("earth_apollo17")
```
)
