-- Regression coverage for the blink.cmp completion stack.
--
-- Phase 2 collapsed 9 plugins (nvim-cmp + cmp-buffer/path/cmdline/nvim-lua +
-- cmp-under-comparator + cmp-nvim-lsp + cmp-nvim-lsp-signature-help + LuaSnip)
-- into a single blink.cmp spec backed by Neovim's native `vim.snippet`.
--
-- Scope note: these assert the wiring this repo owns - which plugins exist,
-- which snippet backend is in use, that a source really produces items through
-- the UI, and that completion capabilities actually reach language servers.
-- They deliberately do not re-test blink's own menu behaviour for every source;
-- the headless child cannot drive keyword-triggered completion reliably, and a
-- flaky test is worse than none. Full source coverage (LSP items, snippets,
-- cmdline, signature help, docs popup) is verified interactively against a live
-- server instead - see docs/tui-observation.md.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- Typing into the child is fussier than it looks; this form was picked by
-- measuring the alternatives, not by taste:
--
--   * `child.type_keys` / `nvim_input` only *queue* keys, and the queue gets
--     interleaved with the RPC calls used to observe the result - the buffer
--     ends up with mangled text like "icompp[`yri".
--   * `nvim_feedkeys(..., 'x')` runs the keys immediately but consumes the
--     whole typeahead, which drops out of insert mode and closes the menu
--     before it can be inspected.
--   * `nvim_feedkeys(..., 'nt')` queues them as if typed without terminating
--     insert mode; the following RPC round-trip is what actually drains them.
--
-- The drain must happen before any `vim.wait()` polling: `vim.wait()` blocks
-- the child's main loop, so pending typeahead would never be processed while it
-- spins and the wait could never succeed, no matter the timeout.
--
-- Note `nvim_replace_termcodes` is *not* used - with `from_part = true` it
-- mangles plain text - so special keys must be written as raw control chars.
local function feed(keys)
  child.lua([[vim.api.nvim_feedkeys(..., 'nt', false)]], { keys })
  child.api.nvim_eval('1')
end

-- blink drops its very first completion request after startup while its fuzzy
-- backend initialises - interactively you never notice because the next
-- keystroke re-triggers, but a test that types once and waits would hang
-- forever. So ask explicitly and retry a bounded number of times, each attempt
-- polling the real `is_visible()` condition rather than sleeping a guessed
-- amount. Requesting the menu directly also keeps this test about "is the
-- source wired up and does it return items", not about blink's auto-trigger
-- heuristics, which are upstream's concern.
local function show_and_wait()
  return child.lua_get([[
        (function()
          local blink = require('blink.cmp')
          for _ = 1, 10 do
            blink.show()
            if vim.wait(500, function() return blink.is_visible() end, 20) then return true end
          end
          return false
        end)()
    ]])
end

local function menu_labels()
  return child.lua_get([[
        (function()
          local ok, list = pcall(function()
            return require('blink.cmp.completion.list').items or {}
          end)
          if not ok then return {} end
          local out = {}
          for _, item in ipairs(list) do out[#out + 1] = item.label end
          return out
        end)()
    ]])
end

local function contains(haystack, needle)
  for _, v in ipairs(haystack) do
    if tostring(v):find(needle, 1, true) then
      return true
    end
  end
  return false
end

T['plugins'] = new_set()

T['plugins']['blink.cmp replaced the whole nvim-cmp cluster'] = function()
  eq(child.lua_get([[require('lazy.core.config').plugins['blink.cmp'] ~= nil]]), true)
  for _, gone in ipairs { 'nvim-cmp', 'LuaSnip', 'cmp-nvim-lsp', 'cmp-nvim-lsp-signature-help' } do
    eq({ gone, child.lua_get(([[require('lazy.core.config').plugins[%q] ~= nil]]):format(gone)) }, { gone, false })
  end
end

T['plugins']['autopairs stands on its own, not as a cmp dependency'] = function()
  eq(child.lua_get([[require('lazy.core.config').plugins['nvim-autopairs'] ~= nil]]), true)
end

T['snippets'] = new_set()

T['snippets']['run on native vim.snippet, with no snippet engine plugin'] = function()
  eq(child.lua_get([[require('blink.cmp.config').snippets.preset]]), 'default')
  eq(child.lua_get([[package.loaded['luasnip'] ~= nil]]), false)
  -- friendly-snippets is kept purely as a data dependency
  eq(child.lua_get([[require('lazy.core.config').plugins['friendly-snippets'] ~= nil]]), true)
end

T['sources'] = new_set()

-- Asserts the *effective* config, not what the spec happens to spell out: most
-- of these now come from blink's own defaults rather than from our opts, and
-- the point is that the behaviour the old cmp cluster provided is still there
-- either way.
T['sources']['configured source set matches the replaced cmp sources'] = function()
  eq(child.lua_get([[require('blink.cmp.config').sources.default]]), { 'lsp', 'path', 'snippets', 'buffer' })
  -- carried over from cmp-buffer's `keyword_length = 6`
  eq(child.lua_get([[require('blink.cmp.config').sources.providers.buffer.min_keyword_length]]), 6)
  -- replaces cmp-nvim-lsp-signature-help
  eq(child.lua_get([[require('blink.cmp.config').signature.enabled]]), true)
  -- replaces cmp-cmdline
  eq(child.lua_get([[require('blink.cmp.config').cmdline.enabled]]), true)
end

-- End-to-end through the real menu. The path source is used because it is fully
-- local and deterministic: no language server, no network, and the fixture is
-- this repository itself.
T['sources']['path source produces real entries in the menu'] = function()
  child.lua([[vim.cmd('enew!')]])
  -- Seeded through the API so no quote character has to survive the
  -- keystream; only the trailing slash that triggers the source is typed.
  -- The path is wrapped in `"` because blink deliberately ignores a bare
  -- leading `/` (it reads that as a comment or URL slash).
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'p = "' .. vim.fn.getcwd() })]])
  feed('A/')

  eq(show_and_wait(), true)
  local labels = menu_labels()
  eq({ 'has lua/', contains(labels, 'lua') }, { 'has lua/', true })
  eq({ 'has tests/', contains(labels, 'tests') }, { 'has tests/', true })
end

T['menu mode'] = new_set()

-- The completion menu is an insert/cmdline-mode object, and blink can be made
-- to open it in normal mode. Upstream race, understood and not ours to fix
-- (v1.10.2 is the latest release): `lib/cmdline_events.lua` hooks `vim.on_key`,
-- checks `mode == 'c'` at key time, then defers the reaction with
-- `vim.schedule`; submitting the cmdline runs the command first, so
-- `trigger.show()` lands in normal mode against the buffer just opened. Typing
-- `:edit foo.lua<CR>` left a 33-item snippet menu floating over a normal-mode
-- buffer that ate the next keys typed - observed since the Phase 6 TUI work,
-- confirmed a real bug by the user 2026-08-06, root-caused here by wrapping
-- `trigger.show` in a live TUI and reading the traceback.
--
-- `blink-cmp.lua` answers it as an invariant (any menu opened outside
-- insert/cmdline closes itself) rather than by patching that one path.
--
-- Both directions in one case on purpose. "The menu is not visible" alone
-- passes just as well when the menu never opened - which in a headless child,
-- where keyword-triggered completion is unreliable (see this file's header), is
-- exactly what would happen. So the guard is cleared first and the menu is
-- shown *through the same entry point the bug uses*, proving it does open in
-- normal mode here, before proving the guard closes it.
T['menu mode']['a menu opened in normal mode closes itself'] = function()
  local show_in_normal_mode = [[
    vim.cmd('stopinsert')
    require('blink.cmp.completion.trigger').show()
  ]]
  -- `child.lua` for the wait (it takes arguments and may hold statements) and
  -- `child.lua_get` for the read (it takes an expression) - the two are not
  -- interchangeable, and a `local` in the latter is a syntax error.
  local function settle(want)
    child.lua(
      [[
        local want = ...
        vim.wait(2000, function() return require('blink.cmp').is_menu_visible() == want end)
      ]],
      { want }
    )
    return child.lua_get([[{ require('blink.cmp').is_menu_visible(), vim.api.nvim_get_mode().mode }]])
  end

  -- with the guard: the same call the bug makes leaves nothing behind
  child.lua(show_in_normal_mode)
  eq(settle(false), { false, 'n' })

  -- and now the half that stops the above from being vacuous: without the
  -- guard the menu really does open, in normal mode, in this very child.
  -- Cleared last so nothing has to put it back.
  child.lua([[vim.api.nvim_clear_autocmds({ group = 'ucw_blink_menu_mode' })]])
  child.lua(show_in_normal_mode)
  eq(settle(true), { true, 'n' })
end

T['lsp'] = new_set()

-- Guards the bug this phase actually uncovered: cmp-nvim-lsp merged its
-- capabilities through `ucw.lsp.register_on_server_setup`, which is installed by
-- monkey-patching `lspconfig.util.on_setup`. Servers are enabled via
-- mason-lspconfig's `automatic_enable`, i.e. native `vim.lsp.enable()`, which
-- never goes through that path - so the hook fired zero times and the merge had
-- silently stopped happening. blink registers on `vim.lsp.config('*')` instead.
T['lsp']['completion capabilities are advertised to every server'] = function()
  local caps = child.lua_get([[vim.lsp.config['*'].capabilities]])
  eq(caps.textDocument.completion.completionItem.snippetSupport, true)
  eq(caps.textDocument.completion.completionItem.labelDetailsSupport, true)
  eq(caps.textDocument.completion.completionItem.resolveSupport ~= nil, true)
  -- include_nvim_defaults=true must be passed, otherwise blink returns only
  -- its own completion capabilities and everything Neovim advertises by
  -- default (signatureHelp, hover, ...) is dropped on the floor
  eq({ 'signatureHelp', caps.textDocument.signatureHelp ~= nil }, { 'signatureHelp', true })
  eq({ 'hover', caps.textDocument.hover ~= nil }, { 'hover', true })
end

return T
