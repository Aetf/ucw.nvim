-- The single registration point for language servers.
--
-- Adding a server means adding one line here. That drives three things:
--   * `vim.lsp.enable()`                    (lua/ucw/lsp/init.lua)
--   * mason-lspconfig's `ensure_installed`  (lua/ucw/plugins/mason-lspconfig.lua)
--   * the `ft =` trigger that loads the LSP stack at all (same specs)
--
-- Optional per-server settings live in `after/lsp/<name>.lua`, which Neovim
-- discovers by itself; a server with nothing to customize gets no file.
--
-- Why the filetypes are written out instead of read from nvim-lspconfig:
-- lazy.nvim needs the `ft` list to decide whether to load nvim-lspconfig at
-- all, so it cannot come from nvim-lspconfig. To keep the duplication honest,
-- tests/test_lsp.lua asserts every list here is *exactly* the resolved
-- `vim.lsp.config[name].filetypes`. If an upstream release changes a server's
-- filetypes, that test fails instead of the trigger silently going stale.
return {
  lua_ls = { 'lua' },

  -- Python is basedpyright (types) + ruff (lint); Phase 6 makes ruff the
  -- formatter too. basedpyright rather than pyright: it is the actively
  -- developed fork (more inference, baseline files, inlay hints) and Mason
  -- installs it from PyPI, where pyright is an npm package.
  basedpyright = { 'python' },
  ruff = { 'python' },

  texlab = { 'tex', 'plaintex', 'bib' },

  -- Deliberately narrower than upstream, which claims 19 filetypes including
  -- `text`, `html`, `mail` and `org`. ltex-ls-plus is a JVM grammar checker;
  -- starting one because a .txt file was opened is not what we want. Prose we
  -- actually proofread is LaTeX and Markdown.
  -- `after/lsp/ltex_plus.lua` narrows the server's own `filetypes` to match, so
  -- this list stays the truth about where it attaches.
  ltex_plus = { 'tex', 'plaintex', 'bib', 'markdown' },

  marksman = { 'markdown', 'markdown.mdx' },

  taplo = { 'toml' },
  -- jsonls is `vscode-json-language-server`, a Node script: it needs `node` on
  -- PATH at *runtime*, not just to install. If it silently fails to attach,
  -- check `~/.local/state/nvim/lsp.log` for `env: 'node': No such file or
  -- directory` before suspecting anything here.
  jsonls = { 'json', 'jsonc' },
  clangd = { 'c', 'c.doxygen', 'cpp', 'cpp.doxygen', 'objc', 'objcpp', 'cuda' },

  -- No `rust_analyzer`: rustaceanvim owns that client on purpose (it is built
  -- around owning the lifecycle, which is what gives standalone-file support,
  -- grouped code actions, runnables, expand-macro, ...). Enabling it here too
  -- is what used to attach two clients to every Rust buffer.
  -- See docs/design/phase3-lsp-redesign.md.
}
