local M = {}

M.url = 'kevinhwang91/nvim-ufo'
M.description = 'Modern and high performance fold the preserves color'

M.requires = {
  'promise-async',
}
M.after = {
  'promise-async',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.tui'
  }
}

local function fold_virt_text_handler(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local suffix = ('  %d '):format(endLnum - lnum)
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
          table.insert(newVirtText, {chunkText, hlGroup})
          chunkWidth = vim.fn.strdisplaywidth(chunkText)
          -- str width returned from truncate() may less than 2rd argument, need padding
          if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
          end
          break
      end
      curWidth = curWidth + chunkWidth
  end
  table.insert(newVirtText, {suffix, 'MoreMsg'})
  return newVirtText
end

local utils = require('ucw.utils')
local au = require('au')

local function ufo_color()
  utils.highlight.UfoFoldedBg = 'IncSearch'
end

function M.config()
  -- UFO uses manual folding that unforunately doesn't play well with small foldlevel
  -- TL'DR is vim will immediately close all folds to foldlevel whenever manual folding
  -- is updated, which UFO does a lot, notably at InsertLeave.
  -- See https://github.com/kevinhwang91/nvim-ufo/issues/7
  vim.opt.foldlevel = 99
  vim.opt.foldlevelstart = 99  -- useful when switching from a window with small foldlevel

  -- Using ufo provider needs remap 'zR' and 'zM' to not let them change foldlevel
  vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
  vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)

  -- Use a command to emulate foldlevel on bufenter
  -- FUTURE: not possible yet, maybe after neovim#19155
  -- au.group('ufo-foldlevel-emu', {
  --   { 'BufEnter', '*', function() end},
  -- })

  -- tell any server that we support foldingRange
  require('ucw.lsp').register_on_server_ready('.*', function(server, opts)
    opts.capabilities = opts.capabilities or vim.lsp.protocol.make_client_capabilities()
    opts.capabilities.textDocumentfoldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true
    }
  end)

  require('ufo').setup{
    -- timeout in ms to highlight the range when opening the folded line, 0 to disable
    -- keep this the same as highlight on yank
    open_fold_hl_timeout = 200,
    fold_virt_text_handler = fold_virt_text_handler,
  }

  ufo_color()
  au.group('ufo-color', {
    { 'ColorScheme', '*', ufo_color}
  })
end

return M
