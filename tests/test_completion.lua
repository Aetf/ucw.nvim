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
        if tostring(v):find(needle, 1, true) then return true end
    end
    return false
end

T['plugins'] = new_set()

T['plugins']['blink.cmp replaced the whole nvim-cmp cluster'] = function()
    eq(child.lua_get([[require('lazy.core.config').plugins['blink.cmp'] ~= nil]]), true)
    for _, gone in ipairs({ 'nvim-cmp', 'LuaSnip', 'cmp-nvim-lsp', 'cmp-nvim-lsp-signature-help' }) do
        eq(
            { gone, child.lua_get(([[require('lazy.core.config').plugins[%q] ~= nil]]):format(gone)) },
            { gone, false }
        )
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
