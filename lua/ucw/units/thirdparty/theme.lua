local M = {}

M.url = 'RRethy/nvim-base16'
M.description = 'Base16 themes with Treesitter and LSP supports'

M.no_default_dependencies = true

M.activation = {
  wanted_by = {
    'target.base'
  }
}

local utils = require('ucw.utils')
local au = require('au')

function M.config()
  au.ColorScheme = function()
    -- with termguicolors, neovim sets its own term color for 256 mode.
    -- if running gui, we set it to match the soft black palette from Konsole
    -- otherwise we remove any already set colors from color scheme to enable passthrough to terminal
    if utils.is_gui() then
      vim.g.terminal_color_0  = '#3f3f3f'
      vim.g.terminal_color_1  = '#705050'
      vim.g.terminal_color_2  = '#60b48a'
      vim.g.terminal_color_3  = '#dfaf8f'
      vim.g.terminal_color_4  = '#9ab8d7'
      vim.g.terminal_color_5  = '#dc8cc3'
      vim.g.terminal_color_6  = '#8cd0d3'
      vim.g.terminal_color_7  = '#dcdccc'
      vim.g.terminal_color_8  = '#709080'
      vim.g.terminal_color_9  = '#dca3a3'
      vim.g.terminal_color_10 = '#72d5a3'
      vim.g.terminal_color_11 = '#f0dfaf'
      vim.g.terminal_color_12 = '#94bff3'
      vim.g.terminal_color_13 = '#ec93d3'
      vim.g.terminal_color_14 = '#93e0e3'
      vim.g.terminal_color_15 = '#ffffff'
    else
      for i=0,15 do
        vim.g[string.format('terminal_color_%d', i)] = nil
      end
    end

    -- additional small fixes that I like
    -- mostly copied from fnune/base16-vim
    local base16 = require('base16-colorscheme')
    local colors = base16.colors

    local hi = utils.highlight

    -- basic ones
    hi.Italic = { italic = true }
    hi.Whitespace = { fg = colors.base03 }
    hi.Deprecated = { strikethrough = true }
    hi.SearchMatch = { fg = colors.base0C }

    -- window
    hi.VertSplit = { fg = colors.base01, bg = colors.base00 }
    hi.LineNr = { fg = colors.base03, bg = colors.base00 } -- dimer line number

    -- folding
    hi.FoldColumn = { fg = colors.base03, bg = colors.base00 }
    hi.Folded = { fg = colors.base02, bg = colors.base00 }

    -- plugin: nvim-cmp
    hi.CmpItemAbbrDeprecated = 'Deprecated'
    hi.CmpItemAbbrMatch = 'SearchMatch'
    hi.CmpItemAbbrMatchFuzzy = 'SearchMatch'
    hi.CmpItemKindText = 'TSText'
    hi.CmpItemKindMethod = 'TSMethod'
    hi.CmpItemKindFunction = 'TSFunction'
    hi.CmpItemKindConstructor = 'TSConstructor'
    hi.CmpItemKindField = 'TSField'
    hi.CmpItemKindVariable = 'TSVariable'
    -- hi.CmpItemKindClass = 'TS'
    hi.CmpItemKindInterface = 'TSText'
    -- hi.CmpItemKindModule = 'TS'
    hi.CmpItemKindProperty = 'TSProperty'
    hi.CmpItemKindUnit = 'TSKeyword'
    -- hi.CmpItemKindValue = 'TS'
    -- hi.CmpItemKindEnum = 'TS'
    hi.CmpItemKindKeyword = 'TSKeyword'
    -- hi.CmpItemKindSnippet = 'TS'
    -- hi.CmpItemKindColor = 'TS'
    -- hi.CmpItemKindFile = 'TS'
    -- hi.CmpItemKindReference = 'TS'
    -- hi.CmpItemKindFolder = 'TS'
    -- hi.CmpItemKindEnumMember = 'TS'
    hi.CmpItemKindConstant = 'TSConstant'
    -- hi.CmpItemKindStruct = 'TS'
    -- hi.CmpItemKindEvent = 'TS'
    hi.CmpItemKindOperator = 'TSOperator'
    hi.CmpItemKindTypeParameter = 'TSType'

    -- plugin: neo-tree
    -- See ":help neo-tree-highlights" for a list of available highlight groups
    hi.NeoTreeDirectoryName = 'Function'
    hi.NeoTreeDirectoryIcon = 'NeoTreeDirectoryName'
    hi.NeoTreeDimText = 'Whitespace'
  end

  vim.cmd [[colorscheme base16-eighties]]
end

return M
