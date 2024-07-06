import Logging

@kwdef struct Log
    level::Logging.LogLevel
    message::String
    attached::Dict{String, FormattedResult}
end

struct JlyfishLogger <: Logging.AbstractLogger
    logs::Vector{Log}

    JlyfishLogger() = new(Log[])
end

reset!(logger::JlyfishLogger) = empty!(logger.logs)

function Logging.handle_message(
    logger::JlyfishLogger, 
    level, message, _module, group, id, file, line; kwargs...
)
    processed_kwargs = Dict(
        string(kwarg.first) => find_best_representation(kwarg.second, [], false)
        for kwarg in kwargs
    )
    push!(
        logger.logs,
        Log(
            level = level.level, 
            message = message, 
            attached = processed_kwargs,
        )
    )
end

Logging.shouldlog(::JlyfishLogger, level, _module, group, id) = level >= Logging.Info
Logging.min_enabled_level(::JlyfishLogger) = Logging.Info

