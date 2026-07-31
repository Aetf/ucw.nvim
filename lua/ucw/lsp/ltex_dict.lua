--[[
Dictionary / false-positive / disabled-rule persistence for ltex-ls-plus.

ltex's `_ltex.addToDictionary`, `_ltex.hideFalsePositives` and
`_ltex.disableRules` are off-spec commands: the server asks the *client* to
remember the word, and offers no storage of its own. This module is that
storage, in the same on-disk layout VSCode's ltex extension uses
(`ltex.<prop>.<lang>.txt`), so a project's `.vscode/` directory works in both
editors:

  <root>/.vscode/ltex.dictionary.en-US.txt        per project
  stdpath('data')/ltex/ltex.dictionary.en-US.txt  global fallback

Phase 3 notes:
  * The command handlers used to be installed through lspconfig's `on_init`.
    They are a plain `commands` table on the config now - `commands` is a
    documented **table** field of `vim.lsp.ClientConfig`
    (runtime/lua/vim/lsp/client.lua:72), so it deep-merges like any other data
    and needs no function-field hook at all.
  * Loading the dictionaries used to happen in `on_new_config`, which stopped
    firing entirely. It runs on `LspAttach` now, sharing one code path with the
    reload that follows each command - the same unification `ucw.lsp.vscode`
    got, for the same reason.
--]]

local F = vim.fn
local Path = require('plenary.path')

local utils = require('ucw.utils')
local lu = require('ucw.lsp.utils')

local M = {}

-- the server name in nvim-lspconfig's registry; ltex-ls upstream is abandoned,
-- this is the maintained fork
local SERVER = 'ltex_plus'

local PROPS = { 'dictionary', 'hiddenFalsePositives', 'disabledRules' }

---@param root_dir? Path|string nil selects the global (single-file) store
---@return Path
local function get_settings_dir(root_dir)
  local res = Path:new(F.stdpath('data')) / 'ltex'
  if root_dir then
    res = Path:new(root_dir) / '.vscode'
  end

  res:mkdir({ parents = true, exists_ok = true })
  return res
end

-- Read external files in settings dir and add their content to settings
---@param settings table<string, any>
---@param settings_dir Path
---@param prop string
local function read_prop(settings, settings_dir, prop)
  local dict = utils.prop_get_table(settings, 'ltex.' .. prop)

  local files = F.readdir(settings_dir.filename)
  for _, entry in pairs(files) do
    local matches, _, lang = entry:find('ltex%.' .. prop .. '%.(.+)%.txt')
    if matches then
      local path = Path:new(settings_dir, entry)
      local langWords = utils.prop_get_table(dict, lang)

      for item in path:iter() do
        if item and item:len() > 0 then
          utils.tbl_insert_uniq(langWords, item)
        end
      end
    end
  end
end

---@param settings_dir Path
---@param prop string
---@param dict table<string, string[]>
local function write_prop(settings_dir, prop, dict)
  for lang, list in pairs(dict) do
    local filepath = settings_dir / string.format('ltex.%s.%s.txt', prop, lang)
    F.writefile(list, filepath.filename, 'a')
  end
end

---@param settings table<string, any>
---@param settings_dir Path
local function load_dicts(settings, settings_dir)
  for _, prop in ipairs(PROPS) do
    read_prop(settings, settings_dir, prop)
  end
end

---Re-read every store and push the result to the server.
---@param client vim.lsp.Client
local function reload(client)
  local settings = client.settings or {}
  load_dicts(settings, get_settings_dir())
  if client.root_dir then
    load_dicts(settings, get_settings_dir(client.root_dir))
  end
  client.settings = settings
  client:notify('workspace/didChangeConfiguration', { settings = settings })
end

--[[
Development notes - the command payloads, as observed on the wire:

_ltex.addToDictionary
arguments = { { uri = "file:///…/text.md", words = { ["en-US"] = { "orloj" } } } }

_ltex.hideFalsePositives
arguments = { { uri = "file:///…/paper.tex", falsePositives = { ["en-US"] = { '{"rule":…}' } } } }

_ltex.disableRules
arguments = { { uri = "file:///…/text.md", ruleIds = { ["en-US"] = { "UPPERCASE_SENTENCE_START" } } } }
--]]
---@param prop string
---@param arg_prop string
---@return fun(cmd: lsp.Command, ctx: table)
local function make_cmd(prop, arg_prop)
  return function(cmd, ctx)
    local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    local root = lu.locate_root_for_doc(client, cmd.arguments[1].uri)

    write_prop(get_settings_dir(root), prop, cmd.arguments[1][arg_prop])
    reload(client)
  end
end

---The `commands` table for `after/lsp/ltex_plus.lua`.
M.commands = {
  ['_ltex.addToDictionary'] = make_cmd('dictionary', 'words'),
  ['_ltex.hideFalsePositives'] = make_cmd('hiddenFalsePositives', 'falsePositives'),
  ['_ltex.disableRules'] = make_cmd('disabledRules', 'ruleIds'),
}

---Its own `LspAttach` autocmd, not a callback registered with `ucw.lsp` - the
---whole point of dropping `ucw.lsp.hooks` is that server-specific behaviour
---needs no private API of this config.
function M.setup()
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('ucw.lsp.ltex', { clear = true }),
    desc = 'ucw: load ltex dictionaries for the attached workspace',
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == SERVER then
        reload(client)
      end
    end,
  })
end

return M
