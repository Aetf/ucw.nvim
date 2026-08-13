--[[
The three off-spec `_ltex.*` commands, which are the only ltex-specific thing
left in this config.

`_ltex.addToDictionary`, `_ltex.hideFalsePositives` and `_ltex.disableRules` are
not in the LSP spec: the server asks the *client* to remember the word, and
offers no storage of its own. The storage is a text file next to the project's
`settings.json`, in the layout VSCode's LTeX extension defines and reads back
implicitly:

  <root>/.vscode/ltex.dictionary.en-US.txt        per project
  <global>/ltex.dictionary.en-US.txt              user scope, when there is no project

Reading those files is **not** this module's job. They are `.vscode` settings,
so `ucw.lsp.vscode` reads them along with everything else in that directory
(its `SIDECAR_KEYS`); this module only writes one and then asks for a recompute.
That is the whole point of the split: `client.settings` has exactly one writer,
so nothing here can un-learn what something else put there, and no event or
contract is needed between the two. See
docs/design/phase3-settings-composition.md.

Phase 3 history worth keeping: these handlers used to be installed through
lspconfig's `on_init`. They are a plain `commands` table on the config now -
`commands` is a documented **table** field of `vim.lsp.ClientConfig`
(runtime/lua/vim/lsp/client.lua:72), so it deep-merges like any other data and
needs no function-field hook at all.
--]]

local F = vim.fn

local lu = require('ucw.lsp.utils')
local vscode = require('ucw.lsp.vscode')

local M = {}

--[[
Development notes - the command payloads, as observed on the wire:

_ltex.addToDictionary
arguments = { { uri = "file:///…/text.md", words = { ["en-US"] = { "orloj" } } } }

_ltex.hideFalsePositives
arguments = { { uri = "file:///…/paper.tex", falsePositives = { ["en-US"] = { '{"rule":…}' } } } }

_ltex.disableRules
arguments = { { uri = "file:///…/text.md", ruleIds = { ["en-US"] = { "UPPERCASE_SENTENCE_START" } } } }
--]]
---Which settings key each command feeds, and which argument carries the payload.
---These are the same keys `ucw.lsp.vscode` reads back out of the directory.
local COMMANDS = {
  ['_ltex.addToDictionary'] = { key = 'ltex.dictionary', arg = 'words' },
  ['_ltex.hideFalsePositives'] = { key = 'ltex.hiddenFalsePositives', arg = 'falsePositives' },
  ['_ltex.disableRules'] = { key = 'ltex.disabledRules', arg = 'ruleIds' },
}

---Append entries to the per-variant sidecar files under `dir`, creating the
---directory if it is not there yet. Creating it *here*, on the write path, is
---the difference between a `.vscode/` that exists because something was saved
---into it and one that exists because something was looked for in it - the
---latter used to appear in every project that ever opened a prose file.
---@param dir string
---@param key string dotted settings key
---@param by_variant table<string, string[]>
local function write_entries(dir, key, by_variant)
  F.mkdir(dir, 'p')
  for variant, list in pairs(by_variant) do
    F.writefile(list, vscode.sidecar_path(dir, key, variant), 'a')
  end
end

---@param spec { key: string, arg: string }
---@return fun(cmd: lsp.Command, ctx: table)
local function handler(spec)
  return function(cmd, ctx)
    local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    local root = lu.locate_root_for_doc(client, cmd.arguments[1].uri)
    local dir = root and vscode.workspace_dir(root.filename) or vscode.global_dir()

    -- `cmd.arguments` is `lsp.LSPAny[]`, so indexing into it yields the whole
    -- LSPAny union rather than the `table<string, string[]>` ltex actually
    -- sends here. Narrowing it would mean asserting a shape the server already
    -- guarantees; the surrounding code is the documentation of that shape.
    ---@diagnostic disable-next-line: param-type-mismatch
    write_entries(dir, spec.key, cmd.arguments[1][spec.arg])
    vscode.reload(client)
  end
end

---The `commands` table for `after/lsp/ltex_plus.lua`.
M.commands = {}
for name, spec in pairs(COMMANDS) do
  M.commands[name] = handler(spec)
end

return M
