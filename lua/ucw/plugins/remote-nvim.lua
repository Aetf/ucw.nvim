return {
  'amitds1997/remote-nvim.nvim',
  cond = require('ucw.targets').is_full_ui,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('remote-nvim').setup {
      devpod = {
        docker_binary = 'podman'
      },
      remote = {
        copy_dirs = {
          config = {
            compression = {
              enabled = true,
            },
          },
        },
      },
      client_callback = function(port, workspace_config)
        local os_info = vim.loop.os_uname()
        local sysname = os_info.sysname
        if sysname == "Darwin" then
          local script = [[
              tell application "iTerm2"
                tell current window
                  create tab with profile profile name of current session of current tab command "%s --server localhost:%s --remote-ui"
                end tell
              end tell
          ]]
          script = script:format(vim.fn.exepath('nvim'), port)
          vim.system({ 'osascript' }, {
            stdin = script,
            detach = true,
          })
        elseif vim.fn.executable("neovide") == 1 then
          local cmd = ('neovide --server localhost:%s'):format(port)
          vim.fn.jobstart(cmd, {
            detach = true,
            on_exit = function(job_id, exit_code, event_type)
              print("Client", job_id, "exited with code", exit_code, "Event type:", event_type)
            end
          })
        elseif sysname == "Linux" then
          local cmd = ('konsole -e nvim --server localhost:%s --remote-ui'):format(port)
          vim.fn.jobstart(cmd, {
            detach = true,
            on_exit = function(job_id, exit_code, event_type)
              print("Client", job_id, "exited with code", exit_code, "Event type:", event_type)
            end
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
        separator = { left = "", right = "" },
      })
      lualine.setup(config)
    end
  end,
}
