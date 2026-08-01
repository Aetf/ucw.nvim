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
    return child.lua_get([[
        (function(suffix, lines)
          local path = vim.fn.tempname() .. suffix
          vim.fn.writefile(lines, path)
          vim.cmd.edit(path)
          return path
        end)(...)]], { suffix, lines })
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
    return child.lua_get([[
        (function(n)
          local levels = {}
          for i = 1, n do levels[i] = vim.fn.foldlevel(i) end
          return table.concat(levels, ' ')
        end)(...)]], { n })
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
        'root:', '  a: 1', '  b: 2', '  c:', '    d: 3', '    e: 4',
        'other:', '  f: 5', '  g: 6',
    })
    -- Same check ufo.lua's `has_parser` makes. Note `language.add` returns
    -- `nil, err` instead of raising, so a `pcall` around it always succeeds -
    -- the return value is what has to be tested.
    eq(child.lua_get([[
        (function()
          local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
          return lang ~= nil and vim.treesitter.language.add(lang) == true
        end)()]]), false)

    eq(wait_for_provider(), 'indent')
    -- Whatever the structure, the point is that folds still exist: preferring
    -- treesitter must not leave parser-less filetypes with nothing.
    eq(child.lua_get([[vim.fn.foldlevel(2) > 0]]), true)
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
    child.restart({})
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
    child.restart({})
    child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp
    child.lua([[require('ucw.options')]])

    eq(child.lua_get([[require('ucw.targets').is_full_ui()]]), true)
    -- ucw.options must not pre-empt ufo here; 'foldexpr' stays at its default.
    eq(child.lua_get([[vim.o.foldexpr]]), '0')
end

return T
