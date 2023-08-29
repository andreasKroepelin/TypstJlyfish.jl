using JSON
import Pkg
import FileWatching

function find_best_representation(result, output_dir)
    mimes = MIME.(("image/svg+xml", "image/png", "image/jpg", "text/plain"))

    function to_output(mime::MIME"text/plain", x)
        str = let iob = IOBuffer()
            @invokelatest show(iob, mime, x)
            String(take!(iob))
        end
        (mime = "text/plain", data = str)
    end
    
    suffix(::MIME"image/svg+xml") = ".svg"
    suffix(::MIME"image/jpg") = ".jpg"
    suffix(::MIME"image/png") = ".png"

    function to_output(mime::Union{MIME"image/svg+xml", MIME"image/png", MIME"image/jpg"}, x)
        file = tempname(output_dir) * suffix(mime)
        open(file, "w") do io
            @invokelatest show(io, mime, x)
        end
        (mime = string(mime), data = file)
    end

    for mime in mimes
        showable(mime, result) || continue
        return to_output(mime, result)
    end

    # no MIME worked
    (mime = "text/plain", data = "!! Result could not be displayed !!")
    
end

function run(
    typst_file;
    evaluation_file = "julia-evaluated.json",
    output_dir = "julia-evaluated-files"
)
    if !isfile(evaluation_file)
        write(evaluation_file, JSON.json([]))
    end
    if !isdir(output_dir)
        mkpath(output_dir)
    end

    query_cmd = `typst query $typst_file --field value "<julia-code>"`
    stdout_file = tempname()
    while true
        query_str = read(query_cmd, String)
        query = JSON.parse(query_str)
        codes = [value["code"] for value in query]

        Pkg.activate(; temp = true)
        eval_module = Module()
        outputs = String[]
        results = []
        for code in codes
            open(stdout_file, "w") do my_stdout
                redirect_stdout(my_stdout) do
                    result = Core.eval(eval_module, Meta.parseall(code))
                    push!(results, find_best_representation(result, output_dir))
                end
            end
            output = read(stdout_file, String)
            push!(outputs, output)
        end
        Pkg.activate(".")
        out_json = JSON.json([
            (; output, result)
            for (output, result) in zip(outputs, results)
        ])
        write(evaluation_file, out_json)
        FileWatching.watch_file(typst_file)
    end
end
