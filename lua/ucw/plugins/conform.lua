-- No `formatters_by_ft` here - that lives per filetype in `ftplugin/<ft>.lua`
-- (`require('conform').formatters_by_ft.<ft> = ...`), next to that filetype's
-- other settings, the same convention `ftplugin/tex.lua` and
-- `ftplugin/just.lua` already use for buffer-local options. Safe regardless of
-- load order because conform is `lazy = false` below, so it is always loaded
-- before any buffer's `ftplugin` runs; conform itself reads `formatters_by_ft`
-- fresh on every format call, not a value captured at `setup()` time.
-- See docs/design/phase6-format-lint.md §2a/§3.
--
-- `lazy = false` rather than gating on `event`/`cmd`/`ft`: measured at ~0.16ms
-- to load (0.03ms sourcing `plugin/conform.lua`, 0.13ms `require('conform')`),
-- smaller than this config's own run-to-run startup jitter. There is also no
-- lazy trigger that would actually keep it unloaded in practice - any
-- `ftplugin/<ft>.lua` calling `require('conform')` forces lazy.nvim to load it
-- immediately regardless of a declared trigger (same mechanism documented in
-- `lua/ucw/plugins/rustaceanvim.lua`'s `mason-registry` comment).
--
-- No `cond = is_full_ui`, unlike lspconfig.lua/mason-lspconfig.lua: conform
-- has no UI surface of its own to gate (it shells out to CLI formatters or
-- falls back to whatever LSP client is already attached), so there is
-- nothing about firenvim/vscode-neovim it needs to avoid. Gating it the same
-- way as the LSP stack turned `<leader>lf`'s `fn` action kind (which
-- `require()`s its target by name and errors if that fails, on purpose - see
-- lua/ucw/lsp/actions.lua) into a hard "module 'conform' not found" crash
-- under those two targets - and, one layer down, made every
-- `ftplugin/<ft>.lua` in this phase throw `E5113` on its first line the
-- moment such a buffer was opened there. See
-- docs/design/phase6-acceptance-review.md R1.
--
-- What *is* context-dependent is `format_on_save` below, not the module:
-- being loaded costs 0.16ms and answers a keypress, while a `BufWritePre`
-- hook rewrites text on its own. Those are two different decisions and the
-- gate belongs on the second one only.
return {
  'stevearc/conform.nvim',
  lazy = false,
  opts = {
    -- Conform's own default is `lsp_format = 'never'`: a filetype with no
    -- `formatters_by_ft` entry and no override gets no formatting at all,
    -- which would regress `<leader>lf` for every filetype this phase didn't
    -- touch (clangd, ltex, rust-analyzer, ...) versus today's
    -- `vim.lsp.buf.format()`, which reaches whatever attached client offers
    -- it. `'fallback'` (try LSP only when no formatter is configured) keeps
    -- that reach. Filetypes that need this blocked (lua_ls's own formatter
    -- vs. stylua; texlab's vs. this config's hand-tuned tex `formatexpr`)
    -- override it locally in their own `ftplugin/<ft>.lua` entry - see
    -- docs/design/phase6-format-lint.md §1.1/§1.5 for why both are real
    -- traps, not hypothetical ones.
    default_format_opts = {
      lsp_format = 'fallback',
    },
    -- Deliberately no `lsp_format` override here: it would be call-site opts,
    -- which conform resolves *before* any `formatters_by_ft`-level override,
    -- so a blanket value here would silently overrule every per-filetype
    -- decision at once - e.g. `'never'` would also turn off Rust's fallback
    -- to rust-analyzer, which this phase does not want to touch. See
    -- docs/design/phase6-format-lint.md §2 D2.
    --
    -- A function rather than a table so the embedded contexts can opt out:
    -- conform calls it per write and skips formatting entirely when it
    -- returns nil (`conform/init.lua`'s `BufWritePre` callback). Returning
    -- the same `{ timeout_ms = 500 }` table everywhere else keeps D2 exactly
    -- as designed for normal desktop use.
    --
    -- Why the embedded contexts opt out: in firenvim, `BufWrite` is not
    -- "save a file", it is *the* mechanism firenvim uses to push the buffer
    -- back into the web page it is editing (its own README: "Firenvim simply
    -- uses the BufWrite event in order to detect when it needs to write
    -- Neovim's buffers to the page"), and this config's own firenvim spec
    -- forces `filetype=markdown` on `github.com_*.txt` - so an unconditional
    -- `format_on_save` puts `prettier` between the user's prose and the
    -- comment box on every sync. vscode-neovim likewise owns its own save
    -- pipeline (and its own format-on-save setting). Neither is a place for
    -- this config to rewrite text unasked; `<leader>lf` still formats there,
    -- which is the difference between explicit and automatic.
    -- See docs/design/phase6-format-lint.md r6.
    format_on_save = function(_bufnr)
      if not require('ucw.targets').is_full_ui() then
        return
      end
      return { timeout_ms = 500 }
    end,
  },
}
