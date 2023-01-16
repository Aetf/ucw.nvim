local M = {}

M.url = 'Tastyep/structlog.nvim'
M.description = 'Structured Logging for nvim, using Lua'

M.no_default_dependencies = true

M.activation = {
  wanted_by = {
    'target.base'
  }
}

local pending_notify_calls = {}

-- lazy load nvim notify to decouple nvim-notify from this
local function lazy_nvim_notify(...)
  local args = {...}
  local ok, nvim_notify = pcall(require, 'notify')
  if not ok then
    -- store in pending calls, they will be displayed in NotifyLoaded autocmd
    table.insert(pending_notify_calls, args)
    return
  end

  nvim_notify(unpack(args))
end

local function flush_pending_notify()
  local nvim_notify = require('notify')
  for idx, args in ipairs(pending_notify_calls) do
    nvim_notify(unpack(args))
  end
end

function M.config()
  local log = require('structlog')
  log.configure({
    ucw = {
      pipelines = {
        {
          level = log.level.INFO,
          processors = {
            log.processors.StackWriter({ "line", "file" }, { max_parents = 0, stack_level = 0 }),
            log.processors.Timestamper("%H:%M:%S"),
          },
          formatter = log.formatters.FormatColorizer(
            "%s [%s] %s: %-30s",
            { "timestamp", "level", "logger_name", "msg" },
            { level = log.formatters.FormatColorizer.color_level() }
          ),
          sink = log.sinks.Console(),
        },
        {
          level = log.level.WARN,
          processors = {},
          formatter = log.formatters.Format(
            "%s",
            { "msg" },
            { blacklist = { "level", "logger_name" } }
          ),
          sink =  log.sinks.NvimNotify(lazy_nvim_notify),
        },
        {
          level = log.level.TRACE,
          processors = {
            log.processors.StackWriter({ "line", "file" }, { max_parents = 3 }),
            log.processors.Timestamper("%H:%M:%S"),
          },
          formatter = log.formatters.Format(
            "%s [%s] %s: %-30s",
            { "timestamp", "level", "logger_name", "msg" }
          ),
          sink = log.sinks.File("./test.log"),
        },
      }
    },
  })

  -- flush pending notify calls after it is loaded
  local structlog_group = vim.api.nvim_create_augroup('StructLogNotifyLoaded', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    pattern = 'NotifyLoaded',
    callback = flush_pending_notify,
  })
end

return M
