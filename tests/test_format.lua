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
-- `stylua`/`ruff`/`taplo` are real binaries, and the child gets them the way
-- any other process would: inherited from the environment. They are this
-- repo's own pinned copies (`mise.toml`), and `just test` runs through
-- `mise exec`, so the suite formats with the versions the repo names rather
-- than with whatever the host happens to have installed
-- (docs/design/phase6.5-binary-deps.md §2.3). Phase 6 instead pointed the
-- child's `PATH` at *this machine's* `~/.local/share/nvim/mason/bin`, which
-- quietly made "someone has run mason-tool-installer here" a prerequisite of a
-- green suite. `prettier` is covered by shape only, never by execution, and the
-- reason is structural rather than environmental: the thing that would install
-- one is `mason-tool-installer`, whose spec is `cond = is_full_ui` and so never
-- loads in a headless child. (It is *not* that `node` is missing - `mise exec`,
-- which is how `just test` runs, resolves both `node` and `npm` since the
-- machine-side PATH fix. That was the old argument, and it made a guarantee out
-- of an accident; see docs/design/phase7-ci.md §1.2. The 'formatters
-- unavailable' group at the bottom of this file leans on the structural one.)

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- Nothing resolvable on `PATH` at all: the child's own Mason is an empty
-- scratch dir, so this is the state of a machine where no formatter has ever
-- been installed. The `lsp_format = 'never'` cases need it *arranged*, not
-- assumed - once the project's own formatters are reachable (above), "the
-- buffer came back unchanged" would otherwise be indistinguishable from
-- "stylua formatted it", which is not what those cases are about.
local function no_formatters_on_path()
  child.lua([[vim.env.PATH = vim.fn.tempname()]])
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

-- Stands in for `vim.notify` and keeps everything handed to it. conform defers
-- its own notifications through `vim.schedule_wrap` but looks `vim.notify` up
-- at call time (`conform/init.lua`), so replacing it here is enough - no need
-- to reach into noice, whose routing is tests/test_picker.lua's subject.
local function capture_notifications()
  child.lua([[
    _G.__notified = {}
    vim.notify = function(msg, level)
      table.insert(_G.__notified, { msg = msg, level = level })
    end
  ]])
end

-- Waits for the deferred notification rather than for a duration: the format
-- call returns before `vim.schedule` has run the callback, and `vim.wait`
-- drives the event loop until it has.
local function warnings()
  child.lua([[vim.wait(2000, function() return #_G.__notified > 0 end)]])
  return child.lua_get([[
    (function()
      local msgs = {}
      for _, n in ipairs(_G.__notified) do
        if n.level == vim.log.levels.WARN then table.insert(msgs, n.msg) end
      end
      return msgs
    end)()
  ]])
end

T['shape'] = new_set()

-- Queried field-by-field rather than as one table (same reason
-- tests/test_lsp_actions.lua's `wk()` test does): a `formatters_by_ft` entry
-- mixes an array part (formatter names) with a hash part (`lsp_format`),
-- which the RPC bridge to the child cannot marshal whole - `child.lua_get`
-- on `formatters_by_ft.lua` errors with "Cannot convert given Lua table".
T['shape']['formatters_by_ft has exactly the five filetypes this phase configures'] = function()
  for _, ft in ipairs { 'lua', 'python', 'toml', 'markdown', 'tex' } do
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
  return child.lua_get(([[
        (function()
          vim.cmd('enew!')
          vim.bo.filetype = %q
          return vim.lsp.start({
            name = %q,
            cmd = _G.new_fake_format_server(%q),
            root_dir = vim.fn.getcwd(),
          })
        end)()
    ]]):format(filetype, name, marker))
end

T['lsp_format blocking'] = new_set()

-- The trap docs/design/phase6-format-lint.md §1.1 is about: `lua_ls` also
-- advertises `documentFormattingProvider`, and with no `stylua` reachable -
-- the worst case, a machine where nothing has installed one -
-- `lsp_format = 'never'` on the `lua` entry must mean the fake lua_ls-like
-- client's edit never gets applied. The buffer stays exactly what it started
-- as, not "formatted, just by the wrong tool."
T['lsp_format blocking']['lua stays unformatted rather than falling back to a formatting-capable client'] = function()
  no_formatters_on_path()
  local id = start_fake_formatter('lua_ls', 'lua', 'FORMATTED_BY_FAKE')
  eq(id ~= vim.NIL and id ~= nil, true)
  set_lines { 'local x=1' }
  do_format()
  eq(lines(), { 'local x=1' })
end

-- The same buffer with `stylua` reachable, which is the case that actually
-- happens: the client is still there, still advertising formatting, and still
-- must not be the one that wins. Splitting the two states apart is what keeps
-- the case above honest - on its own it passes whether `lsp_format = 'never'`
-- works or merely nothing was installed.
T['lsp_format blocking']['lua formats with stylua, not with the formatting-capable client'] = function()
  local id = start_fake_formatter('lua_ls', 'lua', 'FORMATTED_BY_FAKE')
  eq(id ~= vim.NIL and id ~= nil, true)
  set_lines { 'local x=1' }
  do_format()
  eq(lines(), { 'local x = 1' })
end

-- docs/design/phase6-format-lint.md §1.5: texlab advertises formatting too,
-- and blocking it is the actual fix for the bug this phase almost shipped.
T['lsp_format blocking']['tex stays unformatted rather than falling back to texlab'] = function()
  local id = start_fake_formatter('texlab', 'tex', 'FORMATTED_BY_FAKE')
  eq(id ~= vim.NIL and id ~= nil, true)
  set_lines { '\\documentclass{article}' }
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
  set_lines { 'fn main() {}' }
  child.lua(([[vim.cmd.write(%q)]]):format(path))
  eq(vim.fn.readfile(path), { 'FORMATTED_BY_FAKE' })
  vim.fn.delete(path)
end

-- "No formatter is installed" is a real state of a real machine, not an
-- accident of CI, so both of its halves are specified behaviour: the buffer
-- comes back untouched, *and* the user is told once why. Phase 6.5 built the
-- first half of this axis and skipped the second; this is the rest of it
-- (docs/design/phase7-ci.md §3.4, D8).
--
-- Both assertions live in one case on purpose. "The buffer is unchanged" alone
-- passes just as well when conform never ran at all - which is precisely the
-- failure this is here to notice - and a WARN alone says nothing about what
-- happened to the text.
--
-- `exactly one` rather than `at least one`: conform caches the notification per
-- filetype per session (`has_notified_ft_no_formatters`, Phase 6), so this is
-- only assertable in a fresh child, which `pre_case` gives. It is also what
-- would catch that cache regressing in either direction.
T['formatters unavailable'] = new_set()

-- The `PATH`-stripped state: a machine where nothing has ever been installed.
-- `lua` has an explicit `formatters_by_ft` entry (`stylua`) plus
-- `lsp_format = 'never'`, so there is nothing left to fall back to and the
-- warning is the only thing that happens.
T['formatters unavailable']['lua with nothing on PATH: unchanged buffer and one WARN'] = function()
  no_formatters_on_path()
  capture_notifications()
  child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'lua']])
  set_lines { 'local x=1' }
  do_format()
  eq(warnings(), { 'Formatters unavailable for lua file' })
  eq(lines(), { 'local x=1' })
end

-- markdown needs no arranging at all, which is the point of covering it too:
-- its formatter is `prettier`, `mason-tool-installer` is what would install one
-- and its spec is `cond = is_full_ui`, never true in a headless child. So this
-- is the same behaviour reached *by construction* rather than by stripping the
-- environment - it holds identically on this machine and on a bare runner, and
-- it does not depend on `npm` being absent from either (§1.2).
T['formatters unavailable']['markdown has no formatter anywhere: unchanged buffer and one WARN'] = function()
  capture_notifications()
  child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'markdown']])
  set_lines { '#    title' }
  do_format()
  eq(warnings(), { 'Formatters unavailable for markdown file' })
  eq(lines(), { '#    title' })
end

T['real CLI formatters'] = new_set()

T['real CLI formatters']['stylua formats a lua buffer via <leader>lf'] = function()
  child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'lua']])
  set_lines { 'local x=1' }
  do_format()
  eq(lines(), { 'local x = 1' })
end

T['real CLI formatters']['ruff_format formats a python buffer via <leader>lf'] = function()
  child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'python']])
  set_lines { 'x=1' }
  do_format()
  eq(lines(), { 'x = 1' })
end

T['real CLI formatters']['taplo formats a toml buffer via <leader>lf'] = function()
  child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'toml']])
  set_lines { '[a]', 'x=1' }
  do_format()
  eq(lines(), { '[a]', 'x = 1' })
end

-- `format_on_save` writing the *on-disk* content, not just the in-buffer one
-- - it is a `BufWritePre` hook, and the two can diverge if the autocmd
-- priority/timing is wrong, which a buffer-only assertion would miss.
T['real CLI formatters']['format_on_save reformats a lua file on disk'] = function()
  local path = vim.fn.tempname() .. '.lua'
  child.lua(([[vim.cmd.edit(%q)]]):format(path))
  set_lines { 'local x=1' }
  child.lua('vim.cmd.write()')
  eq(vim.fn.readfile(path), { 'local x = 1' })
  vim.fn.delete(path)
end

T['PATH order'] = new_set()

-- docs/design/phase6.5-binary-deps.md §2.2: `mason.setup { PATH = 'append' }`
-- instead of Mason's default `prepend`. Mason is the compatibility floor, so a
-- copy the project put ahead of it on `PATH` has to win - that is the only
-- mechanism by which a repo's `node_modules/.bin`, `.venv` or `mise.toml` pin
-- reaches the editor at all, and conform's bare `command = 'stylua'`
-- (conform/formatters/stylua.lua) is the shape every consumer of it has.
--
-- The earlier `stylua` is a shell script that ignores its input and prints a
-- marker, because two real stylua builds would be indistinguishable. Both
-- directions are in one case on purpose: a test that only ran the first half
-- would pass under `prepend` too, on any machine where Mason has no `stylua`
-- installed - which is every test child.
T['PATH order']['a stylua ahead of Mason on PATH is the one conform runs'] = function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  vim.fn.writefile({ '#!/bin/sh', 'cat > /dev/null', 'echo AHEAD_OF_MASON' }, dir .. '/stylua')
  vim.fn.setfperm(dir .. '/stylua', 'rwxr-xr-x')

  local inherited = child.lua_get([[vim.env.PATH]])
  child.lua(([[vim.env.PATH = %q .. ':' .. vim.env.PATH]]):format(dir))
  child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'lua']])
  set_lines { 'local x=1' }
  do_format()
  eq(lines(), { 'AHEAD_OF_MASON' })

  child.lua(([[vim.env.PATH = %q]]):format(inherited))
  set_lines { 'local x=1' }
  do_format()
  eq(lines(), { 'local x = 1' })

  vim.fn.delete(dir, 'rf')
end

-- The structural half, and the one that fails the moment someone restores the
-- upstream default: Mason's bin directory must be *last*. `exepath()` answers
-- for the binaries that exist today; this answers for the ones that do not
-- exist yet, which is most of the value of doing it with `PATH` at all.
T['PATH order']['Mason appends its bin directory rather than prepending it'] = function()
  child.lua([[require('lazy').load { plugins = { 'mason.nvim' } }]])
  local entries = child.lua_get([[vim.split(vim.env.PATH, ':', { plain = true })]])
  local mason_bin = child.lua_get([[require('mason-core.installer.InstallLocation').global():bin()]])
  eq(entries[#entries], mason_bin)
end

-- docs/design/phase6-acceptance-review.md R1: `conform.lua` used to carry
-- `cond = require('ucw.targets').is_full_ui`, the same gate lspconfig.lua
-- uses. Unlike `lsp`/`picker` actions (whose backing module - core `vim.lsp`,
-- or `snacks.nvim`, which has no such gate - stays available either way),
-- the `fn` action kind `require()`s its target by name and errors on
-- failure, on purpose (lua/ucw/lsp/actions.lua). With conform gated,
-- `<leader>lf` under firenvim/vscode-neovim did not just fail to format - it
-- raised "module 'conform' not found", replacing the graceful "no matching
-- language servers" `vim.lsp.buf.format()` gave before Phase 6.
--
-- r6 (docs/design/phase6-format-lint.md) grew this group from that one case
-- to four: the class behind R1, the ftplugin path R1's own writeup got
-- backwards, and the half of the R1 fix that went the other way - dropping
-- the `cond` also switched `format_on_save` on in these same contexts.
T['embedded contexts'] = new_set()

-- `H.boot_embedded` reboots the child with the marker set *before*
-- `ucw.boot()`, which is the only moment that matters - see its comment in
-- tests/aux/lua/helpers.lua. It lives there rather than here because
-- tests/test_health.lua needs the same thing for the same reason.
local function boot_embedded(marker)
  H.boot_embedded(child, marker)
end

T['embedded contexts']['<leader>lf does not hard-error under vscode-neovim'] = function()
  boot_embedded('vscode')
  child.lua([[vim.cmd('enew!'); vim.bo.filetype = 'lua']])
  local ok = child.lua_get([[(pcall(function()
        require('ucw.lsp.actions').call('format')
    end))]])
  eq(ok, true)
end

-- The generalisation of the case above, in the shape Phase 4's G1 asked for:
-- R1 was not "conform is gated", it was "`fn` is the one action kind that
-- reaches its target through a bare `require()`, so *any* `fn` action backed
-- by a `cond`-gated plugin is a crash in the context that gates it".
-- `format`/`conform` is the only such action today; this is what notices the
-- second one. `lsp` actions reach core `vim.lsp` and `picker` actions reach
-- `snacks.nvim` (no `cond` at all), so neither needs the same guard.
T['embedded contexts']['every fn action can require its module'] = function()
  boot_embedded('vscode')
  local unloadable = child.lua_get([[
        (function()
          local bad = {}
          for name, action in pairs(require('ucw.lsp.actions').actions) do
            if action.fn then
              local ok, err = pcall(require, action.fn.mod)
              if not ok then
                table.insert(bad, ('%s -> %s (%s)'):format(name, action.fn.mod, tostring(err)))
              end
            end
          end
          table.sort(bad)
          return table.concat(bad, '; ')
        end)()
    ]])
  eq(unloadable, '')
end

-- The other half of the same `cond`: with the plugin loading everywhere,
-- every `ftplugin/<ft>.lua` this phase added `require('conform')` on its
-- first line, so a gated conform did not merely disable formatting in the
-- embedded contexts - it threw `E5113` out of the FileType autocmd on the
-- first `.lua`/`.md`/`.py`/`.toml`/`.tex` buffer opened there, before any
-- key was pressed. Nothing bound `<leader>lf` to that; opening a file was
-- enough.
-- Opens real files rather than setting `vim.bo.filetype` on a scratch
-- buffer, and the difference is the whole test: an error raised by an
-- `ftplugin` reaches the caller through `:edit`, but is swallowed when the
-- FileType autocmd is triggered by an option assignment. Written the second
-- way first, this case stayed green with the `cond` put back - the reverse
-- verification Phase 4's F5 rule asks for is what caught that.
T['embedded contexts']['opening a formatted filetype does not raise'] = function()
  boot_embedded('started_by_firenvim')
  local fixtures = {
    { '.lua', 'lua', 'local x = 1' },
    { '.md', 'markdown', '# title' },
    { '.py', 'python', 'x = 1' },
    { '.toml', 'toml', '[a]' },
    -- `\documentclass` so this lands on `tex` rather than `plaintex`,
    -- which has no ftplugin in this config and would quietly not test
    -- anything.
    { '.tex', 'tex', '\\documentclass{article}' },
  }
  for _, fixture in ipairs(fixtures) do
    local suffix, want_ft, content = unpack(fixture)
    local path = vim.fn.tempname() .. suffix
    vim.fn.writefile({ content }, path)
    local got = child.lua_get(([[
            (function()
              local ok, err = pcall(vim.cmd.edit, %q)
              return { ok, ok and vim.bo.filetype or tostring(err) }
            end)()]]):format(path))
    eq({ suffix, got }, { suffix, { true, want_ft } })
    vim.fn.delete(path)
  end
end

-- docs/design/phase6-format-lint.md r6: dropping the `cond` for R1 also
-- switched `format_on_save` on in exactly the contexts that own their own
-- write semantics - in firenvim, `BufWrite` *is* the sync-to-the-webpage
-- mechanism, and this config's own firenvim spec makes github.com text
-- boxes `filetype=markdown`. The formatter is deliberately reachable here
-- (real Mason bin on PATH, the same setup the "real CLI formatters" cases
-- use) so this asserts the gate, not the accident that firenvim sessions
-- never get Mason's bin dir on PATH today.
--
-- Both halves in one case on purpose: the same buffer, the same formatter,
-- one path automatic and one explicit. Asserting only the first would pass
-- just as well if conform had been turned off wholesale, which is the R1
-- regression coming back.
T['embedded contexts']['format_on_save is off, <leader>lf still formats'] = function()
  boot_embedded('started_by_firenvim')
  local path = vim.fn.tempname() .. '.lua'
  child.lua(([[vim.cmd.edit(%q)]]):format(path))
  set_lines { 'local x=1' }
  child.lua('vim.cmd.write()')
  eq(vim.fn.readfile(path), { 'local x=1' })

  do_format()
  eq(lines(), { 'local x = 1' })
  vim.fn.delete(path)
end

return T
