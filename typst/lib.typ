#let juyst-output-data = state("juyst-output-data", ())
#let juyst-code-counter = counter("juyst-code-counter")

#let read-julia-output(data) = {
  assert.eq(type(data), array)
  for evaluation in data {
    assert.eq(type(evaluation), dictionary)
    for k in evaluation.keys() {
      assert(k in ("result", "stdout", "logs", "code"))
    }
  }
  
  just-output-data.update(data)
}

#let jl-raw(
  preferred-mimes: (),
  display: false,
  fn: evaluated => none,
  it
) = {
  if type(preferred-mimes) != array {
    preferred-mimes = (preferred-mimes, )
  }

  [#metadata((
    preferred-mimes: preferred-mimes,
    code: it.text,
    display: display,
  )) <juyst-julia-code>]

  context {
    let id = juyst-code-counter.get()
    let output = juyst-output-data.get()

    let ev = output.at(id, default: none)
    if ev == none {
      [*??*]
    } else if ev.code != it.text {
      // out of sync
      [*??*]
    } else {
      fn(ev)
    }
  }

  juyst-code-counter.step()
}

#let jl(
  preferred-mimes: (),
  code: false,
  result: auto,
  stdout: auto,
  logs: auto,
  it
) = {
  let relevant-result(result) = not (
    result.mime == "text/plain"
    and
    result.data in ("", "nothing")
  )
  let display-result(result) = {
    if result.mime == "text/plain" {
      // set align(bottom)
      set text(fill: red, weight: "bold") if result.failed
      // raw(block: false, lang: "julia-text-output", result.data)
      text(result.data)
    } else if result.mime == "text/typst" {
      eval(result.data, mode: "markup")
    } else if result.mime.starts-with("image/") {
      let format = if result.mime == "image/png" {
        "png"
      } else if result.mime == "image/jpg" {
        "jpg"
      } else if result.mime == "image/svg+xml" {
        "svg"
      }
      image.decode(result.data, format: format)
    } else {
      panic("Unsupported MIME type: " + result.mime)
    }
  }

  let relevant-stdout(output) = output != ""
  let display-stdout(output) = {
    let output-block-selector = raw.where(block: true, lang: "stdout")
    // show output-block-selector: set block(
    //   above: 1pt,
    //   width: 80%,
    //   fill: luma(100),
    //   inset: 3pt,
    // )
    // show output-block-selector: set text(fill: luma(250))

    text(size: .6em)[_stdout:_]
    raw(block: true, lang: "stdout", output)
  }

  let relevant-logs(logs) = logs.len() > 0
  let display-logs(logs) = {
    let display-attachment(attachment) = {
      let (key, val) = attachment
      ( raw(key + " ="), display-result(val) )
    }

    let display-attachments(attached) = if attached.len() > 0 {
      set text(size: .6em)
      grid( columns: 2, column-gutter: .8em, row-gutter: .3em,
        ..attached.pairs().map(display-attachment).flatten()
      )
    }

    let icons = (
      (min: 2000, color: red, text: [e]),
      (min: 1000, color: orange, text: [w]),
      (min: 0, color: aqua, text: [i]),
      (min: -calc.inf, color: gray, text: [d]),
    )

    let display-log(log) = {
      let icon = icons.find(it => log.level >= it.min)

      (
        text(fill: gray, weight: "bold")[log],
        // text(fill: icon.color, weight: "bold", icon.text),
        align(bottom, {
          text(size: .8em, eval(log.message, mode: "markup"))
          display-attachments(log.attached)
        })
      )
    }

    grid(
      columns: (auto, 1fr), column-gutter: 1em, row-gutter: .5em,
      ..logs.map(display-log).flatten()
    )
  }
  
  let fn(evaluated) = {
    if code {
      it
    }
    if result != false and relevant-result(evaluated.result) {
      display-result(evaluated.result)
    }
    if stdout != false and relevant-stdout(evaluated.stdout) {
      display-stdout(evaluated.stdout)
    }
    if logs != false and relevant-logs(evaluated.logs) {
      display-logs(evaluated.logs)
    }
  }

  jl-raw(preferred-mimes: preferred-mimes, display: true, fn: fn, it)
}

