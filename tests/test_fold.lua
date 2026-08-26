-- Regression coverage for the fold stack after Phase 4.
--
-- Phase 4 made fold ownership explicit: nvim-ufo owns folding in the full UI,
-- native `vim.treesitter.foldexpr()` owns it in the embedded contexts
-- (firenvim/vscode), and nothing else sets fold options behind their backs.
-- Before that, `treesitter.lua` also set 'foldmethod'/'foldexpr' globally -
-- inert wherever ufo loaded, load-bearing wherever it did not.
--
-- The most valuable case here is the last one. The embedded contexts never
-- appear in interactive testing, which is exactly how Phase 3 shipped a rust
-- buffer with no keymaps: the tests only ever exercised the main path.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

local function open_fixture(suffix, lines)
  return child.lua_get(
    [[
        (function(suffix, lines)
          local path = vim.fn.tempname() .. suffix
          vim.fn.writefile(lines, path)
          vim.cmd.edit(path)
          return path
        end)(...)]],
    { suffix, lines }
  )
end

-- ufo computes fold ranges asynchronously, so poll the real condition (a
-- provider has been selected for this buffer) rather than sleeping a guess.
local function wait_for_provider()
  return child.lua_get([[
        (function()
          local fold = require('ufo.fold')
          local buf = vim.api.nvim_get_current_buf()
          vim.wait(10000, function()
            local fb = fold.get(buf)
            return fb ~= nil and fb.selectedProvider ~= nil
          end, 20)
          local fb = fold.get(buf)
          return fb and fb.selectedProvider or 'none'
        end)()]])
end

local function fold_levels(n)
  return child.lua_get(
    [[
        (function(n)
          local levels = {}
          for i = 1, n do levels[i] = vim.fn.foldlevel(i) end
          return table.concat(levels, ' ')
        end)(...)]],
    { n }
  )
end

-- A vimscript file: has a (bundled) treesitter parser, has no LSP server in
-- lua/ucw/lsp/servers.lua. That combination is the whole point - it is the case
-- ufo's default `{'lsp', 'indent'}` used to serve with indent folds.
local vim_fixture = {
  'function! Foo()',
  '  if 1',
  '    echo "a"',
  '    echo "b"',
  '  endif',
  'endfunction',
  '',
  'function! Bar()',
  '  echo "c"',
  '  echo "d"',
  'endfunction',
}

-- Indent-foldable Lua: a bundled parser *and* a `folds` query, so nothing about
-- the language keeps ufo's treesitter provider away from it.
local lua_fixture = {
  'local function outer()',
  '  local t = {',
  '    a = 1,',
  '    b = 2,',
  '  }',
  '  return t',
  'end',
  '',
  'local function second()',
  '  return 42',
  'end',
}

-- A file Neovim detects as `help` from its modeline. `buftype` stays empty
-- because it is an ordinary file, not `:help` - which matters: both ufo
-- providers bail early on a `help` buftype, so only this shape reaches the
-- selector. `vimdoc` is one of the seven parsers bundled with Neovim, and
-- there is no `vimdoc/folds.scm` anywhere, which is the combination that broke.
local help_fixture = {
  '*fixture.txt*',
  '',
  '==============================================================================',
  'INTRO                                                        *fixture-intro*',
  '',
  'Some text',
  '  indented a',
  '  indented b',
  '',
  'More text',
  '  indented c',
  '  indented d',
  '',
  ' vim:tw=78:ts=8:ft=help:norl:',
}

-- An in-process language server that advertises folding and answers with fixed
-- ranges, the same trick tests/test_lsp.lua uses: `cmd` may be a function
-- returning an RPC object, so this needs no binary and no subprocess. The test
-- child has a scratch XDG_DATA_HOME, so no real server is installed in it.
local FAKE_FOLDING_SERVER = [[
  function _G.new_folding_server(ranges)
    return function(dispatchers)
      local closing, id = false, 0
      return {
        request = function(method, _, callback)
          id = id + 1
          if method == 'initialize' then
            callback(nil, {
              capabilities = { foldingRangeProvider = true },
              serverInfo = { name = 'fake-folding' },
            })
          elseif method == 'textDocument/foldingRange' then
            callback(nil, ranges)
          else
            callback(nil, nil)
          end
          return true, id
        end,
        notify = function(method)
          if method == 'exit' then dispatchers.on_exit(0, 15) end
          return true
        end,
        is_closing = function() return closing end,
        terminate = function() closing = true end,
      }
    end
  end
]]

local function any_line_folded()
  return child.lua_get([[
        (function()
          for i = 1, vim.api.nvim_buf_line_count(0) do
            if vim.fn.foldlevel(i) > 0 then return true end
          end
          return false
        end)()]])
end

T['provider selection'] = new_set()

T['provider selection']['prefers treesitter over indent when a parser exists'] = function()
  open_fixture('.vim', vim_fixture)
  eq(child.lua_get([[vim.bo.filetype]]), 'vim')
  eq(child.lua_get([[#vim.lsp.get_clients { bufnr = 0 }]]), 0)

  eq(wait_for_provider(), 'treesitter')
  -- Both functions folded, and the `if` block nested inside the first one.
  -- The indent provider used to give "1 1 1 1 1 0 0 0 0 0 0" here: one flat
  -- fold, no nesting, and no fold at all for the second function.
  eq(fold_levels(11), '1 2 2 2 2 1 0 1 1 1 1')
end

T['provider selection']['falls back to indent with no parser and no LSP'] = function()
  open_fixture('.conf', {
    'root:',
    '  a: 1',
    '  b: 2',
    '  c:',
    '    d: 3',
    '    e: 4',
    'other:',
    '  f: 5',
    '  g: 6',
  })
  -- Same check ufo.lua's `has_parser` makes. Note `language.add` returns
  -- `nil, err` instead of raising, so a `pcall` around it always succeeds -
  -- the return value is what has to be tested.
  eq(
    child.lua_get([[
        (function()
          local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
          return lang ~= nil and vim.treesitter.language.add(lang) == true
        end)()]]),
    false
  )

  eq(wait_for_provider(), 'indent')
  -- Whatever the structure, the point is that folds still exist: preferring
  -- treesitter must not leave parser-less filetypes with nothing.
  eq(child.lua_get([[vim.fn.foldlevel(2) > 0]]), true)
end

-- The case the first version of `has_parser` got wrong. A loadable parser is
-- not enough: ufo's treesitter provider raises UfoFallbackException when the
-- language has no `folds` query, and since it sits in providers[2] there is
-- nothing left to fall back to - the buffer got no folds at all, plus an
-- UnhandledPromiseRejection. Indent folds are the right answer here.
T['provider selection']['falls back to indent when the parser has no fold query'] = function()
  open_fixture('.txt', help_fixture)
  eq(child.lua_get([[vim.bo.filetype]]), 'help')
  -- not `:help`, an ordinary file - otherwise both providers bail on buftype
  eq(child.lua_get([[vim.bo.buftype]]), '')

  -- The two halves `has_parser` has to check, asserted separately so a
  -- failure says which one moved.
  eq(child.lua_get([[vim.treesitter.language.add('vimdoc') == true]]), true)
  eq(child.lua_get([[#vim.treesitter.query.get_files('vimdoc', 'folds')]]), 0)

  eq(wait_for_provider(), 'indent')
  eq(any_line_folded(), true)
end

-- The path most buffers actually take, and the one with no coverage at all
-- before: a server that advertises `foldingRangeProvider` wins over both.
T['provider selection']['uses the LSP provider when the server advertises folding'] = function()
  open_fixture('.vim', vim_fixture)
  child.lua(FAKE_FOLDING_SERVER)
  child.lua([[
        vim.lsp.start({
          name = 'fake-folding',
          cmd = _G.new_folding_server({
            -- LSP folding ranges are 0-based and end-inclusive: lines 2-5.
            { startLine = 1, endLine = 4 },
          }),
        }, { bufnr = 0 })
    ]])

  eq(wait_for_provider(), 'lsp')
  -- The server's ranges, not treesitter's - which would have nested the `if`
  -- block and folded the second function too.
  eq(fold_levels(11), '0 1 1 1 1 0 0 0 0 0 0')
end

-- The same providers[2] escape as the fold-query case above, one level further
-- out, and the one that actually fires in daily use: ufo's treesitter provider
-- raises UfoFallbackException on a `nofile` buffer too, and its LSP provider
-- rejects with the same exception, so nothing is left to catch it. ufo attaches
-- on BufWinEnter and that includes floating windows, so every `K` hit this - the
-- hover float is `nofile` with `filetype=markdown`, a language that does have a
-- parser and a fold query, so `has_parser` alone happily picked treesitter.
T['provider selection']['falls back to indent on a nofile buffer'] = function()
  -- Built the way a plugin builds one: scratch (so `buftype` is `nofile` from
  -- birth, before ufo caches it) with a filetype, then displayed.
  child.lua(
    [[
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, ...)
        vim.bo[buf].filetype = 'lua'
        vim.api.nvim_set_current_buf(buf)
    ]],
    { lua_fixture }
  )
  eq(child.lua_get([[vim.bo.buftype]]), 'nofile')
  -- `lua` clears `has_parser` on both counts, so only the buftype gate can
  -- keep treesitter out of providers[2] here.
  eq(child.lua_get([[vim.treesitter.language.add('lua') == true]]), true)
  eq(child.lua_get([[#vim.treesitter.query.get_files('lua', 'folds') > 0]]), true)

  eq(wait_for_provider(), 'indent')
  eq(any_line_folded(), true)
  -- The other half of the symptom, and the only half a user without folds in
  -- a scratch buffer would ever notice.
  eq(
    child.lua_get([[
        vim.api.nvim_exec2('messages', { output = true }).output
          :find('UnhandledPromiseRejection') ~= nil]]),
    false
  )
end

T['full UI'] = new_set()

T['full UI']['ufo owns the fold options'] = function()
  open_fixture('.vim', vim_fixture)
  wait_for_provider()

  -- ufo materialises its ranges as manual folds, which is why 'foldlevel'
  -- has to be 99 - see lua/ucw/plugins/ufo.lua.
  eq(child.lua_get([[vim.wo.foldmethod]]), 'manual')
  eq(child.lua_get([[vim.wo.foldlevel]]), 99)
end

-- D1 kept ufo for exactly two things core has no answer for. Both live in the
-- UI layer, so neither shows up in buffer state - they have to be read off the
-- rendered screen, or they can break under an ufo bump with every other
-- assertion in this file still green.
T['full UI']['renders the line count in fold text, and peeks on K'] = function()
  open_fixture('.vim', vim_fixture)
  wait_for_provider()
  -- 'foldlevel' is 99, so nothing is closed until asked.
  child.cmd('normal! 1Gzc')
  eq(child.lua_get([[vim.fn.foldclosed(1)]]), 1)

  -- Same reason as tests/test_tui_screenshot.lua: a notification float lands
  -- over the fold line and this scan reads the float instead. Measured on
  -- `NVIM v0.13.0-dev`, where neo-tree's startup error made it reproducible -
  -- the row came back as `function! Foo()<float border>  Error  ...`.
  -- Whether the config raises an error at all is tests/test_neotree.lua's case.
  child.lua([[pcall(function() Snacks.notifier.hide() end)]])

  local row
  for _, line in ipairs(child.get_screenshot().text) do
    local text = table.concat(line)
    if text:find('function! Foo') then
      row = text
      break
    end
  end
  eq(row ~= nil, true)
  -- `fold_virt_text_handler` appends `  <folded lines> `; the fold spans
  -- lines 1-6, so the count is 5.
  eq(row:match('(%d+)%s*$'), '5')

  -- `K` is `ucw.keys.actions.hoverK`: ufo's peek first, LSP hover second.
  -- `:normal` without `!` so this goes through the mapping.
  child.cmd('normal K')
  eq(
    child.lua_get([[
        (function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_config(win).relative ~= '' then return true end
          end
          return false
        end)()]]),
    true
  )
end

T['full UI']['nothing sets a global foldexpr behind ufo'] = function()
  -- treesitter.lua used to set 'foldexpr' globally. It was overwritten
  -- per-window by ufo, so it looked harmless, while actually being the only
  -- thing configuring folds in the contexts where ufo does not load.
  eq(child.lua_get([[vim.go.foldexpr]]), '0')
end

T['embedded contexts'] = new_set()

T['embedded contexts']['use native treesitter folds and start folded'] = function()
  -- Boot only `ucw.options` with the firenvim marker set, which is the one
  -- place the "which engine folds" branch is written. A full boot cannot be
  -- used: the helper's `pre_case` boots the config before any test code runs,
  -- so the target is already decided by then.
  child.restart {}
  child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp
  child.g.started_by_firenvim = true
  child.lua([[require('ucw.options')]])

  eq(child.lua_get([[require('ucw.targets').is_full_ui()]]), false)
  eq(child.lua_get([[vim.o.foldmethod]]), 'expr')
  eq(child.lua_get([[vim.o.foldexpr]]), 'v:lua.vim.treesitter.foldexpr()')
  -- Cramped layout: open files mostly folded. This is a deliberate choice,
  -- not the leftover `foldlevel = 1` it used to be.
  eq(child.lua_get([[vim.o.foldlevel]]), 1)
end

T['embedded contexts']['leave fold options alone in the full UI'] = function()
  child.restart {}
  child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp
  child.lua([[require('ucw.options')]])

  eq(child.lua_get([[require('ucw.targets').is_full_ui()]]), true)
  -- ucw.options must not pre-empt ufo here; 'foldexpr' stays at its default.
  eq(child.lua_get([[vim.o.foldexpr]]), '0')
end

return T
