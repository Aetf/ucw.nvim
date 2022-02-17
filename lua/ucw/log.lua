
local logger = nil

local M = {}

function M.log()
    if logger then
        return logger
    end
    local log = require('structlog')
    logger = log.Logger("name", {
        log.sinks.Console(
            log.level.DEBUG
            {
                processors = {
                    log.processors.Namer(),
                    log.processors.Timestamper("%H:%M:%S"),
                },
                formatter = log.formatters.Format( --
                    "%s [%s] %s: %-30s",
                    { "timestamp", "level", "logger_name", "msg" }
                ),
            }
        ),
    })
    return logger
end

return M
