-- Grammar/spell checking for prose. ltex-ls upstream is abandoned; ltex-ls-plus
-- is the maintained fork, which nvim-lspconfig ships a config for.
--
-- Table fields only, and here it really bites: upstream defines
-- `get_language_id`, the function that maps `bib` -> bibtex, `tex` -> latex and
-- so on. A function field in this layer would replace it wholesale and every
-- LaTeX file would be checked as if it were plain text.
--
-- `commands` is a table field of vim.lsp.ClientConfig
-- (runtime/lua/vim/lsp/client.lua:72), so the three off-spec `_ltex.*` handlers
-- are plain data - no `on_init` hook needed. Dictionary loading rides on
-- LspAttach, see lua/ucw/lsp/ltex_dict.lua.
local ltex_dict = require('ucw.lsp.ltex_dict')

return {
  -- Upstream claims 19 filetypes, including `text`, `html`, `mail` and `org`.
  -- ltex-ls-plus is a JVM grammar checker; starting one because a .txt file was
  -- opened is not wanted. Keep this in sync with lua/ucw/lsp/servers.lua -
  -- tests/test_lsp.lua asserts the two match, since that list is also the
  -- lazy.nvim `ft` trigger.
  filetypes = { 'tex', 'plaintex', 'bib', 'markdown' },

  -- Upstream only looks for `.git`. An Obsidian vault has `.obsidian/` and
  -- usually no git repo, and without a root the per-project dictionary in
  -- `<root>/.vscode/ltex.*.txt` degrades to the global one - so words added
  -- while writing notes would not stay with the vault. List fields replace
  -- rather than append, hence `.git` is repeated.
  root_markers = { '.obsidian', '.git' },

  commands = ltex_dict.commands,
}
