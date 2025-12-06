local M = {}

M.url = 'amitds1997/remote-nvim.nvim'
M.description = 'Remote development in Neovim'

M.requires = {
  'telescope',
}

M.requisite = {
  'plenary',
  'nui',
}

M.after = {
  'plenary',
  -- 'nui',
  -- 'telescope',
  'lualine',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.tui'
  }
}

function M.config()
  require('remote-nvim').setup{
    devpod = {
      docker_binary = 'podman'
    },
    client_callback = function(port, workspace_config)
      if vim.fn.has('macunix') then
        local script = [[
            tell application "iTerm2"
              tell current window
                create tab with profile profile name of current session of current tab command "%s --server localhost:%s --remote-ui"
              end tell
            end tell
        ]]
        script = script:format(vim.fn.exepath('nvim'), port)
        vim.system({'osascript'}, {
          stdin = script,
          detach = true,
        })
      else
        print("You haven't setup client callback for remote-nvim")
      end
    end
  }

  -- if there is lualine, add a section
  local ok, lualine = pcall(require, 'lualine')
  if ok then
    local config = lualine.get_config()
    table.insert(config.sections.lualine_b, {
        function()
          return vim.g.remote_neovim_host and ("Remote: %s"):format(vim.uv.os_gethostname()) or ""
        end,
        padding = { right = 1, left = 1 },
        separator = { left = "", right = "" },
    })
  end
end

return M

