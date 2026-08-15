-- Config-core toggles, as `Snacks.toggle` objects (Phase 8, D2). What the
-- mechanism buys over the write-only keys these replace: which-key shows live
-- state (icon, color, `Enable`/`Disable` desc re-evaluated at render time),
-- and pressing notifies. Plugin-owned toggles live with their plugin
-- (`gitsigns.lua`); these two belong to the editor itself.
--
-- Called from `which-key.lua`'s `config()`: snacks is a declared dependency
-- there, and which-key being loaded is what lets `Toggle:map`'s
-- `Snacks.util.on_module('which-key', ...)` register the stateful spec
-- immediately instead of waiting.

local M = {}

function M.setup()
  -- Inlay hints, the *global* flag on purpose - and NOT the built-in
  -- `Snacks.toggle.inlay_hints()` factory, which hardcodes `{ bufnr = 0 }` on
  -- both sides (snacks/toggle.lua:206). This config's semantics are
  -- global-flag-with-mirroring: `ucw.lsp.attach` seeds the global flag and
  -- re-asserts it onto each buffer at attach, so the flag *is* the user
  -- preference and a per-buffer toggle here would re-introduce the
  -- two-presses bug (Phase 3 acceptance review, P1) with better cosmetics.
  --
  -- Claiming `id = 'inlay_hints'` also matters: `Snacks.toggle.get(id)` falls
  -- back to *calling the factory* for an unclaimed id, so without this line
  -- anyone doing `get('inlay_hints')` would summon the per-buffer version.
  Snacks.toggle
    .new({
      id = 'inlay_hints',
      name = 'Inlay Hints',
      get = function()
        return vim.lsp.inlay_hint.is_enabled()
      end,
      set = function(state)
        vim.lsp.inlay_hint.enable(state)
      end,
    })
    :map('<leader>lI')

  -- Full diagnostic text rendered below the line, on the current line only.
  --
  -- Was lsp_lines.nvim, which replaced core's `virtual_lines` handler with
  -- its own; core renders the same thing now, so only the toggle survives
  -- (as `ucw.keys.actions.toggle_virtual_lines` until Phase 8 made it this
  -- object). The option is `current_line` - lsp_lines spelled it
  -- `only_current_line`, and the old toggle kept writing that name, which
  -- core silently ignores. The on-state `{ current_line = true }` matches
  -- `options.lua`'s full-UI default, so the first press turns rendering off.
  --
  -- lsp_lines bound this for normal + visual/select + operator-pending;
  -- operator-pending is meaningless for a toggle, the other two are kept.
  Snacks.toggle
    .new({
      id = 'diag_virtual_lines',
      name = 'Diagnostic virtual lines',
      get = function()
        -- plain truthiness, exactly the old toggle's `not cfg.virtual_lines`:
        -- the value is a table when on, `false` (or unset) when off
        return not not vim.diagnostic.config().virtual_lines
      end,
      set = function(state)
        vim.diagnostic.config {
          virtual_lines = state and { current_line = true } or false,
        }
      end,
    })
    :map('<leader>lp', { mode = { 'n', 'v' } })
end

return M
