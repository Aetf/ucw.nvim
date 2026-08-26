-- Coverage for `:checkhealth ucw` (lua/ucw/health.lua, Phase 6.5).
--
-- The health check is the compensation for a limitation the design accepts on
-- purpose: binaries resolve through `PATH`, so a session started outside a
-- project's environment silently gets Mason's floor instead of the project's
-- pin (docs/design/phase6.5-binary-deps.md §1.1). A report nobody verifies is
-- not a compensation, so each state it can report is produced here on purpose
-- and read back.
--
-- The three declared-versus-installed states are staged as *fixtures*, not as
-- real installs: `is_installed()` is a directory stat and the version comes
-- from `mason-receipt.json` (mason-core/package/AbstractPackage.lua), so a
-- `mkdir` and a three-field JSON file put a package into any of them in
-- milliseconds and offline. The alternative - `MasonToolsInstallSync` per
-- state - would download a real binary per case to observe a code path that
-- never looks at one.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- Runs the check and returns the rendered report. `:checkhealth` opens its own
-- window; wipe it so the next call in the same case starts clean.
local function report()
  child.cmd('checkhealth ucw')
  local text = table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  child.cmd('bwipeout!')
  return text
end

local function has_line(text, needle)
  for _, line in ipairs(vim.split(text, '\n', { plain = true })) do
    if line:find(needle, 1, true) then
      return true
    end
  end
  return false
end

-- Puts a package into the child's own scratch Mason root. `version` nil leaves
-- it without a receipt, which is the state the four-year-old `rust-analyzer`
-- was actually in on this machine.
local function fake_install(package, version)
  child.lua(
    [[
        (function(package, version)
          local dir = require('mason-core.installer.InstallLocation').global():package(package)
          vim.fn.mkdir(dir, 'p')
          if version then
            vim.fn.writefile({ vim.json.encode({
              name = package,
              schema_version = '2.0',
              source = { type = 'registry+v1', id = ('pkg:generic/%s@%s'):format(package, version) },
            }) }, dir .. '/mason-receipt.json')
          end
        end)(...)]],
    { package, version }
  )
end

T['declared versus installed'] = new_set()

-- State 1. Every declared package is in it here, because the child's Mason is
-- a scratch directory - which is also the state of a fresh machine, and the
-- state `prettier` is in on this one permanently.
T['declared versus installed']['a declared package that is not installed warns'] = function()
  local text = report()
  eq(has_line(text, 'lua-language-server: declared by ucw.lsp.servers (lua_ls), not installed'), true)
  eq(has_line(text, 'prettier: declared by mason-tool-installer (ensure_installed), not installed'), true)
end

-- State 2, the one that went unnoticed for four years: something is installed
-- that no declaration accounts for, so a fresh machine would not have it and
-- whatever depends on it is broken there and works here.
T['declared versus installed']['an installed package that nothing declares warns'] = function()
  fake_install('shfmt', '3.7.0')
  local text = report()
  eq(has_line(text, 'shfmt: installed, declared by nothing'), true)
end

-- State 3a. Neither runtime installer updates a package it already installed
-- (§3.2), so "declared" does not mean "current" and the gap has to be
-- reported by someone.
T['declared versus installed']['an installed package behind the registry warns'] = function()
  fake_install('stylua', 'v0.0.1')
  local text = report()
  -- Not the registry's current version: that moves upstream, and what is
  -- being asserted is the comparison, not today's answer.
  eq(has_line(text, 'stylua: v0.0.1 installed, registry has '), true)
  -- Discriminating, per §5: each fixture must produce *only* its own state.
  -- Four cases each asserting one string would all pass against a report
  -- that printed all four.
  eq(has_line(text, 'stylua: declared by'), false)
  eq(has_line(text, 'stylua: installed, version unknown'), false)
end

-- State 3b. A receipt too old to carry a version at all - `rust-analyzer`'s
-- Oct 2022 one - reads as installed with nothing to compare, which must not
-- silently pass as "up to date".
T['declared versus installed']['an installed package with no receipt warns'] = function()
  fake_install('rust-analyzer', nil)
  local text = report()
  eq(has_line(text, 'rust-analyzer: installed, version unknown'), true)
  eq(has_line(text, 'rust-analyzer: declared by'), false)
  eq(has_line(text, 'rust-analyzer: installed, declared by nothing'), false)
end

T['resolution'] = new_set()

-- §2.4.1, the line that would have shown `rust-analyzer` coming from Mason
-- since 2022. Both labels in one case: a copy inside Mason's bin directory is
-- the floor, and anything else is something the environment put ahead of it.
-- Asserting only one of them would pass with the label hardcoded.
T['resolution']['labels a Mason copy as the floor and anything earlier as ahead of it'] = function()
  child.lua([[
        local bin = require('mason-core.installer.InstallLocation').global():bin()
        vim.fn.mkdir(bin, 'p')
        vim.fn.writefile({ '#!/bin/sh', 'exit 0' }, bin .. '/marksman')
        vim.fn.setfperm(bin .. '/marksman', 'rwxr-xr-x')
    ]])
  local text = report()
  eq(has_line(text, 'marksman: ') and has_line(text, '(Mason, the floor)'), true)
  -- `stylua` comes from this repo's own `mise.toml`, inherited through the
  -- environment `just test` runs in - the same way any project's pin
  -- reaches the editor (§2.3).
  eq(has_line(text, 'stylua: ') and has_line(text, '(ahead of Mason on PATH)'), true)
end

-- The structural statement behind every label above: `PATH = 'append'`. The
-- report says it in words so that a session which somehow ended up with Mason
-- first says so where someone is looking.
T['resolution']['reports that Mason is last on PATH'] = function()
  eq(has_line(report(), 'Mason is last on PATH - the floor, as intended'), true)
end

-- A binary nothing on this machine provides. The warning is what tells a fresh
-- checkout why markdown never gets formatted.
T['resolution']['reports a declared binary that resolves to nothing'] = function()
  eq(has_line(report(), 'prettier: not on PATH'), true)
end

T['embedded contexts'] = new_set()

-- The same class as docs/design/phase6-acceptance-review.md R1, in a new file:
-- `mason-lspconfig` is `cond`-gated off under the embedded targets, so a bare
-- `require` of it turns `:checkhealth ucw` into a Lua traceback there. Caught
-- exactly this way while writing the module, which is why it reports module
-- availability instead of asking `ucw.targets` what context this is - one
-- owner for the gate, and it is the spec.
T['embedded contexts']['reports Mason as unavailable instead of erroring'] = function()
  H.boot_embedded(child, 'vscode')
  local text = report()
  eq(has_line(text, 'Mason is not available in this context'), true)
  -- and the part that does not depend on Mason still runs
  eq(has_line(text, 'ucw: tree-sitter CLI'), true)
end

return T
