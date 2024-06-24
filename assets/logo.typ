#set page(width: auto, height: auto, margin: 15pt)
#set text(font: "Alegreya")

#let title(t) = text(size: t, fill: blue)[*Juyst*]

#let slogan = text(size: 15pt, fill: black)[
  #set align(left)
  Islands of #text(fill: rgb(22%, 59.6%, 14.9%))[Julia] \
  in a sea of #text(fill: eastern)[Typst]
]

#context {
  let target = measure(slogan).height
  let t = 0pt
  let tracked-title = title(t)
  while measure(tracked-title).height < target and t < 10cm {
    t += 1pt
    tracked-title = title(t)
  }

  grid(
    columns: 2,
    column-gutter: .5em,
    inset: .5em,
    align: horizon,
    tracked-title,
    grid.vline(),
    slogan,
  )
}

