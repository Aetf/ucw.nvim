local M = {}

M.url = 'nvim-lualine/lualine.nvim'
M.description = 'Statusline'

M.wants = {
  'nvim-web-devicons',
  'nvim-gps',
}

M.activation = {
  wanted_by = {
    'target.basic'
  }
}

local function gps_location()
  return require('nvim-gps').get_location()
end

local function gps_available()
  local ok, gps = pcall(require, 'nvim-gps')
  if not ok then
    return false
  end
  return gps.is_available()
end

function M.config()
  require('lualine').setup {
    extensions = {
      'quickfix',
      {
        filetypes = {"neo-tree"},
        sections = {
          lualine_a = {
            function() return vim.fn.fnamemodify(vim.fn.getcwd(), ':~') end,
          }
        }
      }
    },
    sections = {
      lualine_c = {
        { gps_location, cond = gps_available },
      }
    }
  }
end

return M
