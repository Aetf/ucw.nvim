-- Table fields only: upstream nvim-lspconfig defines `on_attach` for
-- basedpyright, and a function field in this layer would replace it outright.
--
-- basedpyright inherits pyright's lack of filesystem watching, so it needs the
-- client to do it: https://github.com/microsoft/pyright/issues/4635. Neovim advertises
-- `didChangeWatchedFiles.dynamicRegistration = false` by default (measured),
-- so this is a real change rather than a restatement.
-- Note client-side watching can be expensive on large repos, see
-- https://github.com/neovim/neovim/issues/23291.
return {
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
  },
}
