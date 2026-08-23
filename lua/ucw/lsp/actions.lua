-- Every LSP action this config exposes, declared once.
--
-- Two consumers bind these: `ucw.lsp.attach` (buffer-local `g`-prefixed keys,
-- only while a client is attached) and `ucw.plugins.which-key` (the global
-- `<leader>l` tree). Before this table they each carried their own copy of the
-- same `<cmd>lua vim.lsp...<cr>` strings, which is how two of them rotted away
-- unnoticed across Neovim releases:
--
--   * `vim.lsp.buf.range_code_action` was removed in Neovim 0.10 - `<M-S-CR>`
--     and `<leader>lA` have been throwing ever since. `code_action()` reads the
--     visual selection itself now, so there is nothing left for it to do.
--   * `vim.lsp.declaration` never existed under that name (`gH`/`<leader>lH`);
--     it is `vim.lsp.buf.declaration`.
--
-- Declaring the entry point as a *path* rather than a direct reference is what
-- makes that testable: a direct `vim.lsp.buf.range_code_action` reference in a
-- keymap table is simply `nil`, which which-key happily accepts as a group, so
-- the breakage stays invisible until the key is pressed. tests/test_lsp.lua
-- resolves every path here instead.
--
-- Which key maps to which action is deliberately NOT decided here - see
-- `attach.lua` and `which-key.lua`. Phase 9 owns the bindings themselves.

local M = {}

---@class ucw.lsp.ActionFn
---@field mod string module to `require`, e.g. 'conform'
---@field fn string function name on that module, e.g. 'format'

---@class ucw.lsp.Action
---@field desc string
---@field lsp? string dotted path under `vim.lsp`, e.g. 'buf.code_action'
---@field args? any[] arguments for the `lsp`/`fn` function
---@field cmd? string ex-command to run instead of an `lsp` call
---@field picker? string a `snacks.picker` source name, e.g. 'lsp_references'
---@field fn? ucw.lsp.ActionFn a `require(mod).fn` entry point outside `vim.lsp`
---@field mode? string|string[] defaults to normal mode

---@type table<string, ucw.lsp.Action>
M.actions = {
  code_action = { desc = 'Code actions', lsp = 'buf.code_action', mode = { 'n', 'x' } },
  rename = { desc = 'Rename the symbol under cursor', lsp = 'buf.rename' },
  -- Phase 6: conform.nvim owns formatting, not `vim.lsp.buf.format` directly -
  -- `default_format_opts`/`formatters_by_ft` (see lua/ucw/plugins/conform.lua
  -- and the per-filetype ftplugin/*.lua files) decide whether that ends up
  -- shelling out to a CLI formatter or falling back to the LSP client, and
  -- duplicating that decision here as `args` would give it two owners.
  format = {
    desc = 'Format the current buffer (or visual selection)',
    fn = { mod = 'conform', fn = 'format' },
    mode = { 'n', 'x' },
  },
  declaration = { desc = 'Go to declaration', lsp = 'buf.declaration' },
  -- `document_highlight`/`clear_references` are gone (Phase 9, D2): reference
  -- highlighting is automatic now (snacks.words, see snacks.lua), so the
  -- manual pair stopped being an action this config exposes.
  codelens_run = { desc = 'Run codelens at current line', lsp = 'codelens.run' },
  -- The navigation half of that same snacks.words highlighting (Phase 9.5,
  -- T6): highlighting the other occurrences of the symbol under the cursor is
  -- only half a feature if nothing walks them. `[r`/`]r` rather than
  -- LazyVim's `[[`/`]]`, which would shadow the native section motions (the
  -- reason snacks.lua declined to bind any jump key at all) - and rather than
  -- a `g`-prefixed pair, because this is previous/next in a sequence, which is
  -- what the bracket family means. `cycle = true`: the last reference wraps to
  -- the first instead of stopping.
  reference_prev = {
    desc = 'Go to previous reference',
    fn = { mod = 'snacks.words', fn = 'jump' },
    args = { -1, true },
  },
  reference_next = {
    desc = 'Go to next reference',
    fn = { mod = 'snacks.words', fn = 'jump' },
    args = { 1, true },
  },
  -- diagnostics are core, not LSP, hence a plain command rather than an
  -- `lsp` path
  diagnostic_float = {
    desc = 'Show diagnostics on the current line',
    cmd = 'lua vim.diagnostic.open_float()',
  },

  -- Picker-backed actions. Phase 5 moved these off Telescope and onto
  -- `snacks.picker`; naming them here is what kept that to one file, as the
  -- comment above predicted.
  --
  -- `picker` is a source name resolved through `Snacks.picker` at press time,
  -- for the same reason `lsp` is a path resolved through `vim.lsp`: a source
  -- renamed upstream then fails by name instead of producing an inert key.
  -- They cannot stay `cmd` entries - snacks has no ex-commands.
  definitions = { desc = 'Go to definition', picker = 'lsp_definitions' },
  type_definitions = { desc = 'Go to type definition', picker = 'lsp_type_definitions' },
  implementations = { desc = 'Go to implementation', picker = 'lsp_implementations' },
  references = { desc = 'Find references', picker = 'lsp_references' },
  -- `lsp_document_symbols` under Telescope, `lsp_symbols` under snacks.
  document_symbols = { desc = 'Symbols in the current buffer', picker = 'lsp_symbols' },
  workspace_symbols = { desc = 'Symbols in the current workspace', picker = 'lsp_workspace_symbols' },
  -- Deliberate behaviour change (Phase 5, D4), not a faithful port: this was
  -- `Telescope diagnostics`, which with no arguments lists *every* open
  -- buffer, while the description right here has always said "current
  -- buffer". snacks splits the two (`diagnostics` vs `diagnostics_buffer`) and
  -- so forces the choice; it is resolved in favour of the label that has been
  -- on screen in which-key all along.
  diagnostics = { desc = 'Diagnostics for current buffer', picker = 'diagnostics_buffer' },
  -- The workspace-wide variant (Phase 9, D3: `<leader>sD`); what `Telescope
  -- diagnostics` with no arguments used to be, see above.
  diagnostics_all = { desc = 'Diagnostics for the whole workspace', picker = 'diagnostics' },

  -- The inlay-hint toggle (`<leader>lI`) is not here: Phase 8 (D2) made it a
  -- `Snacks.toggle` (`ucw.toggles`), which owns the enable/is_enabled pairing
  -- the bespoke `toggle` kind used to encode. The *global*-flag semantics it
  -- must keep (Phase 3 acceptance review, P1) are documented there.
}

---Resolve a dotted path under `vim.lsp`.
---@param path string
---@return any
function M.resolve(path)
  local obj = vim.lsp
  for part in path:gmatch('[^.]+') do
    if type(obj) ~= 'table' then
      return nil
    end
    obj = obj[part]
  end
  return obj
end

---Run a named action. Resolution happens here, at press time, so a removed
---upstream function produces a real error naming the action instead of a
---mysteriously inert key.
---@param name string
function M.call(name)
  local action = M.actions[name]
  if not action then
    error(('unknown LSP action %q'):format(name))
  end

  if action.picker then
    -- Indexing an unknown source on `Snacks.picker` yields nil rather than
    -- raising (`picker/config/init.lua`'s `wrap(..., { check = true })`), so a
    -- source that disappears upstream would otherwise be a silently dead key -
    -- exactly the failure `ucw.lsp.actions` exists to prevent.
    local fn = require('snacks.picker')[action.picker]
    if type(fn) ~= 'function' then
      error(('LSP action %q: snacks.picker.%s is not a source'):format(name, action.picker))
    end
    return fn(unpack(action.args or {}))
  end

  if action.fn then
    -- Same reasoning as `picker`: resolved by name at press time, not a
    -- direct reference, so a renamed/removed function fails loudly instead
    -- of the key going silently inert.
    local ok, mod = pcall(require, action.fn.mod)
    if not ok then
      error(('LSP action %q: require(%q) failed: %s'):format(name, action.fn.mod, mod))
    end
    local fn = mod[action.fn.fn]
    if type(fn) ~= 'function' then
      error(('LSP action %q: %s.%s is not a function'):format(name, action.fn.mod, action.fn.fn))
    end
    return fn(unpack(action.args or {}))
  end

  local fn = M.resolve(assert(action.lsp, ('LSP action %q has no `lsp` path'):format(name)))
  if type(fn) ~= 'function' then
    error(('LSP action %q: vim.lsp.%s is not a function'):format(name, action.lsp))
  end
  return fn(unpack(action.args or {}))
end

---The right-hand side to bind for an action: an ex-command string for the
---`cmd` kind, a closure for the `lsp` and `picker` kinds.
---@param name string
---@return string|function
function M.rhs(name)
  local action = M.actions[name]
  if not action then
    error(('unknown LSP action %q'):format(name))
  end
  if action.cmd then
    return ('<cmd>%s<cr>'):format(action.cmd)
  end
  return function()
    return M.call(name)
  end
end

---Build a which-key v3 spec entry for `lhs` bound to the named action.
---@param lhs string
---@param name string
---@param opts? table extra which-key fields (e.g. `buffer`)
---@return table
function M.wk(lhs, name, opts)
  local action = M.actions[name]
  if not action then
    error(('unknown LSP action %q'):format(name))
  end
  local entry = vim.tbl_extend('error', { lhs, M.rhs(name), desc = action.desc }, opts or {})
  if action.mode then
    entry.mode = action.mode
  end
  return entry
end

return M
