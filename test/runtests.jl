import TypstJlyfish

TypstJlyfish.watch(
    "test.typ";
    typst_args = "--root ..",
    evaluation_file = tempname(),
)
