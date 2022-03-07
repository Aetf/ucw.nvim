--[[
-- Spell checking using LTex
--]]
local utils = require('ucw.utils')
local lu = require('ucw.lsp.utils')

local get_root_dir = lu.lazy_root_pattern('.git', '.vscode')

local function loadWorkspaceDicts(new_config, root_dir)
  -- read .vscode/ltex.dictionary.*.txt and .vscode/ltex.hiddenFalsePositives.*.txt
end

local function cmd_addToDictionary(args)
  vim.notify('cmd addToDictionary ' .. vim.inspect(args[1]))
end

--[[
args[1] = {
  arguments = { {
      falsePositives = {
        ["en-US"] = { '{"rule":"UNLIKELY_OPENING_PUNCTUATION","sentence":"^\\\\Q: Serving Inference Requests for Dynamic Neural Networks\\\\E$"}' }
      },
      uri = "file:///home/aetf/develop/latex/dyninfer-paper/nsdi23/dyninfer-nsdi23.tex"
    } },
  command = "_ltex.hideFalsePositives",
  title = "Hide false positive"
}
--]]
local function cmd_hideFalsePositives(args)
  local root = get_root_dir(args[1].arguments[1].uri)
  vim.notify('cmd hideFalsePositives ' .. vim.inspect(args))
end

local function cmd_disableRules(args)
  vim.notify('cmd disableRules ' .. vim.inspect(args))
end

local lsp_commands_setup_done = false
local function setup_lsp_commands()
  if lsp_commands_setup_done then
    return
  end
  lsp_commands_setup_done = true

  vim.lsp.commands['_ltex.addToDictionary'] = cmd_addToDictionary
  vim.lsp.commands['_ltex.hideFalsePositives'] = cmd_hideFalsePositives
  vim.lsp.commands['_ltex.disableRules'] = cmd_disableRules
end


return function(opts)
  local lspconfig = require('lspconfig')

  opts.root_dir = get_root_dir

  opts.on_new_config = lspconfig.util.add_hook_after(opts.on_new_config, loadWorkspaceDicts)

  -- XXX: move to per-client command after nvim-lspconfig#1750 is fixed
  setup_lsp_commands()
end
