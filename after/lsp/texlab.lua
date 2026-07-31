-- Table fields only: upstream nvim-lspconfig defines `on_attach` for texlab.
--
-- Two root-dependent workarounds the old (dead) `lsp/lang/texlab.lua` carried
-- are deliberately NOT ported:
--
--   * `cmd_env.CHKTEXRC = root_dir`, for texlab#309 - chktex reads `.chktexrc`
--     on Linux while texlab copied `chktexrc` into its temp dir. The issue is
--     closed upstream, and there is no longer a native place to put it anyway:
--     `before_init` runs *after* the process is spawned
--     (runtime/lua/vim/lsp/client.lua:30), so `cmd_env` is already consumed.
--     If it turns out to still be needed, the native home is a function-valued
--     `cmd` (which receives the resolved config and can pass `env` to
--     `vim.lsp.rpc.start`).
--   * `settings.texlab.rootDirectory = root_dir`, for texlab#571 - also closed
--     upstream.
--
-- `root_dir` is not overridden either: it used to be
-- `lazy_root_pattern('.latexmkrc', 'Makefile')`, and upstream's `root_markers`
-- already lists `.latexmkrc`/`latexmkrc`/`.texlabroot`/`Tectonic.toml`/`.git`.
-- `Makefile` is dropped on purpose - it would make any directory with a
-- Makefile a LaTeX project root.
local texlab_sync = require('ucw.lsp.texlab_sync')

return {
  settings = {
    texlab = {
      build = {
        onSave = true,
        forwardSearchAfter = true,
        -- explicitly disable latexmk's own preview modes (-pv/-pvc); the
        -- viewer is driven through forwardSearch below instead
        args = { '-pv-', '-pvc-', '-pdf', '-interaction=nonstopmode', '-synctex=1', '%f' },
        -- was `texlab.auxDirectory` in the old module; texlab deprecated that
        -- spelling in favour of `texlab.build.auxDirectory` (CHANGELOG, #906),
        -- and now also infers it from `latexmkrc` when one exists (#907)
        auxDirectory = 'build',
      },
      chktex = {
        onOpenAndSave = true,
        onEdit = true,
      },
      forwardSearch = texlab_sync.forward_search(),
    },
  },
}
