-- Thin survivor of the old systemd-style "target" concept: context predicates
-- used as `cond = ...` on plugin specs, instead of a custom dependency-graph engine.
local M = {}

function M.is_gui()
  return require('ucw.utils').is_gui()
end

function M.is_firenvim()
  return vim.g.started_by_firenvim == true
end

function M.is_vscode()
  return vim.g.vscode == true
end

function M.is_tui()
  return not M.is_gui() and not M.is_firenvim() and not M.is_vscode()
end

-- the "full" editing UI (tabs/statusline/tree/etc) - everything except the
-- embedded/minimal contexts (firenvim, vscode-neovim)
function M.is_full_ui()
  return not M.is_firenvim() and not M.is_vscode()
end

return M
