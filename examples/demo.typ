#import "../typst/lib.typ": *

#set page(width: 20cm, height: auto, margin: 1cm)

#read-julia-output(cbor("demo-juyst.cbor"))

#show raw: set text(font: "JuliaMono")
#set par(justify: false)
#set align(horizon)

#grid(columns: 2, column-gutter: .5cm,)[
  #set text(size: 8pt)
  ````typ
  #jl(
    ```julia
    import Pkg
    Pkg.add(["Dates", "HTTP", "FileIO", "ImageShow"])
    using Dates, HTTP, FileIO, ImageShow
    ```
  )

  Hello, Juliacon #jl(`year(now())`)!
  This is Juyst, not to be confused with...

  #jl(
    ```julia
    load(HTTP.URI(
      "https://upload.wikimedia.org/wikipedia/commons/thumb/2/28/Karte_Insel_Juist.png/1024px-Karte_Insel_Juist.png"
    ))
    ```
  )
  ````
][
  #set text(font: "Alegreya Sans", size: 20pt)
  #jl(
    ```julia
    import Pkg
    Pkg.add(["Dates", "HTTP", "FileIO", "ImageIO", "ImageShow"])
    using Dates, HTTP, FileIO, ImageIO, ImageShow
    ```
  )

  Hello, Juliacon #jl(`year(now())`)!
  This is Juyst, not to be confused with...

  #{
    set image(width: 9cm)
    jl(
      ```julia

      load(HTTP.URI("https://upload.wikimedia.org/wikipedia/commons/thumb/2/28/Karte_Insel_Juist.png/1024px-Karte_Insel_Juist.png"))
      ```
    )
  }
]
