-- Coverage for Phase 6 (conform.nvim formatting).
--
-- Two different things are tested here, with two different techniques:
--
--   * "does `formatters_by_ft` have the right shape" - pure data, checkable
--     without running any formatter at all. This is also the "consistency"
--     check docs/design/phase6-format-lint.md §4 calls for: §3.2 moved
--     `formatters_by_ft` out of one central table into five separate
--     `ftplugin/<ft>.lua` files, which trades away `grep`-one-file
--     visibility for a forgotten/broken file to hide behind - this is what
--     stands in for it.
--   * "does the `lsp_format` block/fallback actually take effect" - needs a
--     real formatting request dispatched to a real client. Done with
--     in-process fake LSP servers (tests/test_lsp.lua's convention, `cmd` as
--     a function returning an RPC object), not a real language server: the
--     child's XDG_DATA_HOME is a scratch temp dir, so Mason has installed
--     nothing into it - the *absence* of a real formatter there is itself
--     useful, see below.
--
-- `stylua`/`ruff`/`taplo` are real binaries already installed on this
-- machine's actual Mason bin dir (not the child's scratch one) - the CLI
-- formatter cases point the child's `PATH` at that real directory explicitly
-- rather than faking a CLI tool's own output, the same "what's real on this
-- machine" methodology the design doc's own measurements used. `prettier`
-- needs `node`, absent here (the same gap `lua/ucw/lsp/servers.lua` already
-- documents for `jsonls`) - covered by shape only, not execution.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- The real, machine-wide Mason install (this process's own stdpath, not the
-- child's - the child's XDG_DATA_HOME is overridden to a scratch dir by
-- tests/aux/lua/helpers.lua before any of this runs).
local REAL_MASON_BIN = vim.fn.stdpath('data') .. '/mason/bin'

local function use_real_mason_bin()
    child.lua(([[vim.env.PATH = %q .. ':' .. vim.env.PATH]]):format(REAL_MASON_BIN))
end

local function lines()
    return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function set_lines(ls)
    child.api.nvim_buf_set_lines(0, 0, -1, false, ls)
end

local function do_format()
    child.lua([[require('ucw.lsp.actions').call('format')]])
end

T['shape'] = new_set()

-- Queried field-by-field rather than as one table (same reason
-- tests/test_lsp_actions.lua's `wk()` test does): a `formatters_by_ft` entry
-- mixes an array part (formatter names) with a hash part (`lsp_format`),
-- which the RPC bridge to the child cannot marshal whole - `child.lua_get`
-- on `formatters_by_ft.lua` errors with "Cannot convert given Lua table".
T['shape']['formatters_by_ft has exactly the five filetypes this phase configures'] = function()
    for _, ft in ipairs({ 'lua', 'python', 'toml', 'markdown', 'tex' }) do
        child.lua(([[vim.cmd('enew!'); vim.bo.filetype = %q]]):format(ft))
    end
    local keys = child.lua_get([[
        (function()
          local k = {}
          for name, _ in pairs(require('conform').formatters_by_ft) do table.insert(k, name) end
          table.sort(k)
          return k
        end)()
    ]])
    eq(keys, { 'lua', 'markdown', 'python', 'tex', 'toml' })

    local function field(ft, expr)
        return child.lua_get(("require('conform').formatters_by_ft[%q]%s"):format(ft, expr))
    end

    eq(field('lua', '[1]'), 'stylua')
    eq(field('lua', '.lsp_format'), 'never')
    eq(field('python', '[1]'), 'ruff_format')
    eq(field('python', '.lsp_format'), vim.NIL)
    eq(field('toml', '[1]'), 'taplo')
    eq(field('markdown', '[1]'), 'prettier')
    -- no formatter list for tex, only the override - see the fallback test below
    eq(field('tex', '[1]'), vim.NIL)
    eq(field('tex', '.lsp_format'), 'never')
end

-- A language server that lives entirely inside the test child, offering
-- formatting and nothing else. `cmd` may be a function returning an RPC
-- object (runtime/lua/vim/lsp/client.lua:485) - no binary, no subprocess.
local FAKE_FORMAT_SERVER = [[
  function _G.new_fake_format_server(marker)
    return function(dispatchers)
      local closing, id = false, 0
      return {
        request = function(method, _, callback)
          id = id + 1
          if method == 'initialize' then
            callback(nil, { capabilities = { documentFormattingProvider = true }, serverInfo = { name = 'fake' } })
          elseif method == 'textDocument/formatting' then
            callback(nil, {
              {
                range = { start = { line = 0, character = 0 }, ['end'] = { line = 9999, character = 0 } },
                newText = marker .. '\n',
              },
            })
          else
            callback(nil, nil)
          end
          return true, id
        end,
        notify = function(method, _)
          if method == 'exit' then dispatchers.on_exit(0, 15) end
          return true
        end,
        is_closing = function() return closing end,
        terminate = function() closing = true end,
      }
    end
  end
]]

-- Starts a fake, formatting-capable client named `name`, attached to a fresh
-- buffer whose filetype is `filetype`. If the fallback reaches it, the buffer
-- ends up containing exactly `marker`.
local function start_fake_formatter(name, filetype, marker)
    child.lua(FAKE_FORMAT_SERVER)
    return child.lua_get(
        ([[
        (function()
          vim.cmd('enew!')
          vim.bo.filetype = %q
          return vim.lsp.start({
            name = %q,
            cmd = _G.new_fake_format_server(%q),
            root_dir = vim.fn.getcwd(),
          })
        end)()
    ]]):format(filetype, name, marker)
    )
end

T['lsp_format blocking'] = new_set()

-- The trap docs/design/phase6-format-lint.md §1.1 is about: `lua_ls` also
-- advertises `documentFormattingProvider`, and this config's `stylua` is
-- unreachable in this child (its Mason bin is the scratch one, empty - the
-- worst case, matching a machine where mason-tool-installer has not run
-- yet). `lsp_format = 'never'` on the `lua` entry must mean the fake
-- lua_ls-like client's edit never gets applied - the buffer stays exactly
-- what it started as, not "formatted, just by the wrong tool."
T['lsp_format blocking']['lua stays unformatted rather than falling back to a formatting-capable client'] = function()
    local id = start_fake_formatter('lua_ls', 'lua', 'FORMATTED_BY_FAKE')
    eq(id ~= vim.NIL and id ~= nil, true)
    set_lines({ 'local x=1' })
    do_format()
    eq(lines(), { 'local x=1' })
end

-- docs/design/phase6-format-lint.md §1.5: texlab advertises formatting too,
-- and blocking it is the actual fix for the bug this phase almost shipped.
T['lsp_format blocking']['tex stays unformatted rather than falling back to texlab'] = function()
    local id = start_fake_formatter('texlab', 'tex', 'FORMATTED_BY_FAKE')
    eq(id ~= vim.NIL and id ~= nil, true)
    set_lines({ '\\documentclass{article}' })
    do_format()
    eq(lines(), { '\\documentclass{article}' })
end

-- The positive control: an *unlisted* filetype (no `ftplugin/rust.lua`, no
-- `formatters_by_ft.rust` entry at all) must still reach its LSP client via
-- `default_format_opts.lsp_format = 'fallback'` - this is what makes Rust's
-- existing rust-analyzer-does-rustfmt behaviour survive this phase
-- untouched (§1.4). Routed through `:w` / `format_on_save`, not a direct
-- `format()` call, because that is the path r2 almost broke: giving
-- `format_on_save` its own `lsp_format` would have overridden this exact
-- fallback for every filetype at once (§2 D2, §5).
T['lsp_format blocking']['an unlisted filetype (rust) still reaches its LSP fallback on save'] = function()
    local id = start_fake_formatter('rust-analyzer', 'rust', 'FORMATTED_BY_FAKE')
    eq(id ~= vim.NIL and id ~= nil, true)
    local path = vim.fn.tempname() .. '.rs'
    set_lines({ 'fn main() {}' })
    child.lua(([[vim.cmd.write(%q)]]):format(path))
    eq(vim.fn.readfile(path), { 'FORMATTED_BY_FAKE' })
    vim.fn.delete(path)
end

T['real CLI formatters'] = new_set()

T['real CLI formatters']['stylua formats a lua buffer via <leader>lf'] = function()
    use_real_mason_bin()
    child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'lua']])
    set_lines({ 'local x=1' })
    do_format()
    eq(lines(), { 'local x = 1' })
end

T['real CLI formatters']['ruff_format formats a python buffer via <leader>lf'] = function()
    use_real_mason_bin()
    child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'python']])
    set_lines({ 'x=1' })
    do_format()
    eq(lines(), { 'x = 1' })
end

T['real CLI formatters']['taplo formats a toml buffer via <leader>lf'] = function()
    use_real_mason_bin()
    child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'toml']])
    set_lines({ '[a]', 'x=1' })
    do_format()
    eq(lines(), { '[a]', 'x = 1' })
end

-- `format_on_save` writing the *on-disk* content, not just the in-buffer one
-- - it is a `BufWritePre` hook, and the two can diverge if the autocmd
-- priority/timing is wrong, which a buffer-only assertion would miss.
T['real CLI formatters']['format_on_save reformats a lua file on disk'] = function()
    use_real_mason_bin()
    local path = vim.fn.tempname() .. '.lua'
    child.lua(([[vim.cmd.edit(%q)]]):format(path))
    set_lines({ 'local x=1' })
    child.lua('vim.cmd.write()')
    eq(vim.fn.readfile(path), { 'local x = 1' })
    vim.fn.delete(path)
end

-- docs/design/phase6-acceptance-review.md R1: `conform.lua` used to carry
-- `cond = require('ucw.targets').is_full_ui`, the same gate lspconfig.lua
-- uses. Unlike `lsp`/`picker` actions (whose backing module - core `vim.lsp`,
-- or `snacks.nvim`, which has no such gate - stays available either way),
-- the `fn` action kind `require()`s its target by name and errors on
-- failure, on purpose (lua/ucw/lsp/actions.lua). With conform gated,
-- `<leader>lf` under firenvim/vscode-neovim did not just fail to format - it
-- raised "module 'conform' not found", replacing the graceful "no matching
-- language servers" `vim.lsp.buf.format()` gave before Phase 6. Reboots the
-- child with the embedded-context marker set *before* `ucw.boot()` runs,
-- the same technique tests/test_fold.lua's "embedded contexts" group uses,
-- since the standard `pre_case` hook has already booted the full-UI config
-- before any test body runs.
T['embedded contexts'] = new_set()

T['embedded contexts']['<leader>lf does not hard-error under vscode-neovim'] = function()
    local xdg = child.env.XDG_DATA_HOME
    child.restart({})
    child.env.XDG_DATA_HOME = xdg
    child.o.rtp = xdg .. ',' .. child.o.rtp
    child.o.packpath = xdg .. ',' .. child.o.packpath
    child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp
    child.g.vscode = true
    child.lua([[require('ucw').boot()]])
    child.lua([[require('lazy.manage').install()]])

    child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'lua']])
    local ok = child.lua_get([[(pcall(function()
        require('ucw.lsp.actions').call('format')
    end))]])
    eq(ok, true)
end

return T
