import Juyst

Juyst.run(
    "test.typ";
    typst_args = "--root ../../..",
    evaluation_file = tempname(),
)
