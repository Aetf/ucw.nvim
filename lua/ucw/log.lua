local log = require('structlog')

local M = {}

local logger = nil
function M.logger()
    if not logger then
        logger = log.get_logger('ucw')
    end
    return logger
end

return M
