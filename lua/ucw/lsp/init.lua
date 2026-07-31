-- LSP entry point.
--
-- There is no framework here any more. Neovim 0.12's native four-layer config
-- (`vim.lsp.config('*')` -> `<rtp>/lsp/<name>.lua` -> `<rtp>/after/lsp/<name>.lua`
-- -> explicit `vim.lsp.config(name, ...)`) plus `LspAttach` covers everything
-- `ucw.lsp.hooks` used to hand-roll, so this module is only three things: the
-- server list, the filetypes derived from it, and one `setup()` that installs
-- the attach handlers and calls `vim.lsp.enable()`.
--
-- See docs/design/phase3-lsp-redesign.md for the measurements behind that.

local M = {}

local servers = require('ucw.lsp.servers')

---Server names this config runs, sorted for stable output/tests.
---@return string[]
function M.server_names()
  local names = vim.tbl_keys(servers)
  table.sort(names)
  return names
end

---The filetypes that should bring the LSP stack up, i.e. the `ft =` trigger of
---every LSP plugin spec. Sorted and deduplicated.
---@return string[]
function M.filetypes()
  local seen = {}
  local out = {}
  for _, fts in pairs(servers) do
    for _, ft in ipairs(fts) do
      if not seen[ft] then
        seen[ft] = true
        table.insert(out, ft)
      end
    end
  end
  table.sort(out)
  return out
end

local did_setup = false

---Called from the nvim-lspconfig spec's `config`, i.e. the first time a
---buffer of a supported filetype is opened.
---
---Note what is NOT here: `ucw.lsp.attach.setup()`. Attach behaviour has to be
---installed eagerly from `ucw.boot`, because not every client comes from this
---list - rustaceanvim starts its own on `ft=rust`, and nvim-lspconfig never
---loads for a Rust buffer at all. Wiring the handlers here meant a Rust buffer
---got no keymaps and no inlay hints; found by driving a real TUI, invisible to
---anything that only looked at servers we enable ourselves.
function M.setup()
  if did_setup then
    return
  end
  did_setup = true

  vim.lsp.enable(M.server_names())
end

return M
