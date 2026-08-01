local function fold_virt_text_handler(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local suffix = ('  %d '):format(endLnum - lnum)
  local sufWidth = vim.fn.strdisplaywidth(suffix)
  local targetWidth = width - sufWidth
  local curWidth = 0
  for _, chunk in ipairs(virtText) do
    local chunkText = chunk[1]
    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
    if targetWidth > curWidth + chunkWidth then
      table.insert(newVirtText, chunk)
    else
      chunkText = truncate(chunkText, targetWidth - curWidth)
      local hlGroup = chunk[2]
      table.insert(newVirtText, { chunkText, hlGroup })
      chunkWidth = vim.fn.strdisplaywidth(chunkText)
      -- str width returned from truncate() may less than 2rd argument, need padding
      if curWidth + chunkWidth < targetWidth then
        suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
      end
      break
    end
    curWidth = curWidth + chunkWidth
  end
  table.insert(newVirtText, { suffix, 'MoreMsg' })
  return newVirtText
end

local utils = require('ucw.utils')
local au = require('au')

local function ufo_color()
  utils.highlight.UfoFoldedBg = 'IncSearch'
end

-- Does this filetype have a treesitter parser that can actually be loaded?
--
-- Deliberately not "is it listed in treesitter.lua's `ensure_installed`": a
-- parser listed there is not necessarily compiled (this machine has no
-- `tree-sitter` CLI, so only Neovim's bundled parsers exist). Claiming
-- treesitter folds for a language whose parser is missing would leave the
-- buffer with no folds at all, since ufo only consults two providers.
local function has_parser(filetype)
  local lang = vim.treesitter.language.get_lang(filetype)
  return lang ~= nil and vim.treesitter.language.add(lang) == true
end

-- ufo's default is `{'lsp', 'indent'}` (ufo/fold/manager.lua), and it only ever
-- consults providers[1] and providers[2] - so with the default its treesitter
-- provider is unreachable, and every filetype without a configured LSP server
-- folds by indentation. Measurably worse: on an 11-line vimscript file the
-- indent provider gave one flat fold over the first function, no nesting for
-- the block inside it, and no fold at all for the second function, where
-- treesitter got all three right.
--
-- Preferring treesitter also makes the two halves of this config agree: a
-- buffer without LSP now folds by treesitter here *and* in firenvim/vscode,
-- where folds come from `vim.treesitter.foldexpr()` (see ucw.options).
local function provider_selector(_, filetype, _)
  return has_parser(filetype) and { 'lsp', 'treesitter' } or { 'lsp', 'indent' }
end

local function config()
  -- UFO uses manual folding that unforunately doesn't play well with small foldlevel
  -- TL'DR is vim will immediately close all folds to foldlevel whenever manual folding
  -- is updated, which UFO does a lot, notably at InsertLeave.
  -- See https://github.com/kevinhwang91/nvim-ufo/issues/7
  --
  -- Concretely, in ufo/fold/driver.lua every fold update erases all folds
  -- (`zE`), recreates each range with `:fold`, and then restores 'foldlevel' -
  -- and assigning 'foldlevel' closes every fold deeper than it. So this is a
  -- structural requirement of the manual-fold model rather than a preference,
  -- and it is why ucw.options only sets 'foldlevel' for the contexts where ufo
  -- is *not* loaded. Do not "clean it up".
  vim.opt.foldlevel = 99
  vim.opt.foldlevelstart = 99 -- useful when switching from a window with small foldlevel

  -- Using ufo provider needs remap 'zR' and 'zM' to not let them change foldlevel
  vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
  vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)

  -- Tell any server that we support foldingRange.
  --
  -- This used to go through `ucw.lsp.register_on_server_setup`, a hook
  -- monkey-patched onto lspconfig's setup path - which servers stopped taking
  -- once they came up through native `vim.lsp.enable()`, so folding capability
  -- had silently not been advertised to anyone. `vim.lsp.config('*')` is the
  -- native lowest-priority layer, and capabilities is a table, so this merges
  -- with blink.cmp's contribution instead of replacing it.
  --
  -- Ordering matters and is load-bearing: every '*' capability contributor has
  -- to run before the first `vim.lsp.enable()`. This spec is eager and LSP is
  -- `ft`-triggered, so startup strictly precedes it; tests/test_lsp.lua asserts
  -- the merged result rather than trusting that.
  vim.lsp.config('*', {
    capabilities = {
      textDocument = {
        foldingRange = {
          dynamicRegistration = false,
          lineFoldingOnly = true,
        },
      },
    },
  })

  require('ufo').setup {
    -- timeout in ms to highlight the range when opening the folded line, 0 to disable
    -- keep this the same as highlight on yank
    open_fold_hl_timeout = 200,
    fold_virt_text_handler = fold_virt_text_handler,
    provider_selector = provider_selector,
  }

  ufo_color()
  au.group('ufo-color', {
    { 'ColorScheme', '*', ufo_color }
  })
end

return {
  'kevinhwang91/nvim-ufo',
  cond = require('ucw.targets').is_full_ui,
  dependencies = { 'kevinhwang91/promise-async' },
  config = config,
}
