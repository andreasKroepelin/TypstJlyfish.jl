#let setup-julia-eval(
  julia-output: (evaluations: (), images: ()),
  julia-output-images: none,
  result-marker: failed => if failed {
      text(fill: red, weight: "bold", [!])
    } else {
      sym.arrow.r.curve
    },
  stdout-marker: [stdout:],
  logs-marker: [logs:],
  relevant-result: result => not (
      result.mime == "text/plain"
      and
      result.data in ("", "nothing")
    ),
  relevant-stdout: output => output != "",
  relevant-logs: logs => logs.len() > 0,
  not-evaluated: { text(fill: luma(100))[_not evaluated_]; parbreak() },
  max-image-height: 10em,
  display-result: auto,
  display-stdout: auto,
  display-logs: auto,
  code-evaluated: auto,
) = {
  let julia-code-counter = counter("julia-code")
  let julia-output-images-dict = (:)
  for (img-path, img) in julia-output.images.zip(julia-output-images) {
    julia-output-images-dict.insert(img-path, img)
  }
  
  let display-result = if display-result == auto {
    result => (
      result-marker(result.failed),
      {
        if result.mime == "text/plain" {
          set align(bottom)
          set text(fill: red, weight: "bold") if result.failed
          raw(block: true, result.data)
        } else if result.mime.starts-with("image/") {
          let img = julia-output-images-dict.at(result.data)
          style(styles => {
            let height = measure(img, styles).height
            let max-height = measure(v(max-image-height), styles).height
            if height > max-height {
              set image(height: max-height)
              img
            } else {
              img
            }
          })
        } else {
          panic("Unsupported MIME type: " + result.mime)
        }
      }
    )
  } else {
    display-result
  }


  let display-stdout = if display-stdout == auto {
    output => (
      stdout-marker,
      {
        let output-block-selector = raw.where(block: true, lang: "stdout")
        show output-block-selector: set block(
          width: 80%,
          fill: luma(100),
          inset: 3pt,
        )
        show output-block-selector: set text(fill: luma(250))

        raw(block: true, lang: "stdout", output)
      }
    )
  } else {
    display-stdout
  }



  let display-logs = if display-logs == auto {
    let display-attachment(attachment) = {
      let key = attachment.keys().first()
      let val = attachment.values().first()
      ( raw(key + " ="), display-result(val).last() )
    }

    let display-attachments(attached) = if attached.len() > 0 {
      set text(size: .6em)
      grid( columns: 2, column-gutter: .8em, row-gutter: .3em,
        ..attached.map(display-attachment).flatten()
      )
    }

    let icons = (
      (min: 2000, color: red, text: [e]),
      (min: 1000, color: orange, text: [w]),
      (min: 0, color: aqua, text: [i]),
    )

    let display-log(log) = {
      let icon = icons.find(it => log.level >= it.min)

      (
        text(fill: icon.color, weight: "bold", icon.text),
        align(bottom, {
          text(size: .8em, eval(log.message, mode: "markup"))
          display-attachments(log.attached)
        })
      )
    }

    logs => (
      logs-marker,
      grid(
        columns: (auto, 1fr), column-gutter: 1em, row-gutter: .5em,
        ..logs.map(display-log).flatten()
      )
    )
  } else {
    display-logs
  }


  let code-evaluated = if code-evaluated == auto {
    let fn(
      code,
      evaluated,
      show-anything: true,
      show-code: true,
      show-result: auto,
      show-stdout: auto,
      show-logs: auto,
    ) = {
      if show-anything {
        code
        if evaluated != none {
          grid(columns: 2, gutter: 1em,
            ..if show-result == auto and relevant-result(evaluated.result) or show-result == true {
              display-result(evaluated.result)
            },
            ..if show-stdout == auto and relevant-stdout(evaluated.output) or show-stdout == true {
              display-stdout(evaluated.output)
            },
            ..if show-logs == auto and relevant-logs(evaluated.logs) or show-logs == true {
              display-logs(evaluated.logs)
            },
          )
        } else {
          not-evaluated
        }
      }
    }

    fn
  } else {
    code-evaluated
  }

  let julia-eval(
    preferred-mimes: (),
    ..kwargs,
    it
  ) = {
    let preferred-mimes = if type(preferred-mimes) == "array" {
      preferred-mimes
    } else {
      (preferred-mimes, )
    }
    julia-code-counter.display(id => {
      [ #metadata((preferred-mimes: preferred-mimes, code: it.text)) <julia-code> ]

      code-evaluated(it, julia-output.evaluations.at(id, default: none), ..kwargs.named())
    })


    julia-code-counter.step()
  }

  julia-eval
}
