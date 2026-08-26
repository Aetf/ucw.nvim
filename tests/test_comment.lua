-- Regression coverage for commenting after Phase 4.
--
-- Phase 4 deleted Comment.nvim and nvim-ts-context-commentstring in favour of
-- Neovim's own `gc`/`gcc`, which resolves 'commentstring' through treesitter -
-- including injected languages, the single reason ts-context-commentstring was
-- installed. These tests pin that claim down, since it is the only part of the
-- swap that could regress silently: a wrong commentstring still "works", it
-- just comments with the wrong syntax.
--
-- `:normal` (without `!`) is used deliberately: it goes through mappings, so
-- these exercise the real `gcc`/`gc` bindings rather than calling the internal
-- toggle directly. It also avoids the child's feedkeys minefield entirely.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- Markdown with a fenced Lua block: prose commentstring is `<!-- %s -->`,
-- but inside the fence it has to become `-- %s`.
local markdown_fixture = {
  '# Title',
  '',
  'Some prose here.',
  '',
  '```lua',
  'local x = 1',
  'local y = 2',
  '```',
  '',
  'More prose.',
}

local function open_fixture()
  child.lua(
    [[
        local path = vim.fn.tempname() .. '.md'
        vim.fn.writefile(..., path)
        vim.cmd.edit(path)
        -- the treesitter parser is what makes the injection visible to `gc`
        vim.treesitter.start(0)
        -- ...but only once the injections have actually been parsed. `start()`
        -- merely arms the highlighter, which parses on redraw - measured, right
        -- after it `get_parser(0):children()` is still `{}`, and
        -- `vim._comment.get_commentstring` walks exactly that table
        -- (runtime/lua/vim/_comment.lua:54). Every case below was therefore
        -- racing the redraw: `just all` failed 2 runs in 6 on the visual one
        -- and passed the rest, which is worse than failing (Phase 3 acceptance
        -- review, P7). One synchronous full parse removes the race - no sleep,
        -- no retry loop.
        vim.treesitter.get_parser(0):parse(true)
    ]],
    { markdown_fixture }
  )
end

-- `...` anywhere but last in an argument list is truncated to one value, hence
-- the wrapper function rather than inlining it into the api call.
local function lines(from, to)
  return child.lua_get(
    [[
        (function(from, to)
          return vim.api.nvim_buf_get_lines(0, from, to, false)
        end)(...)]],
    { from, to }
  )
end

T['gc'] = new_set { hooks = { pre_case = open_fixture } }

T['gc']['uses the injected language commentstring inside a fence'] = function()
  eq(child.lua_get([[vim.bo.commentstring]]), '<!-- %s -->')
  child.cmd([[normal 6Ggcc]])
  eq(lines(5, 7), { '-- local x = 1', 'local y = 2' })
end

T['gc']['uses the buffer commentstring outside a fence'] = function()
  child.cmd([[normal 3Ggcc]])
  eq(lines(2, 3), { '<!-- Some prose here. -->' })
end

T['gc']['honours a count'] = function()
  child.cmd([[normal 1G3gcc]])
  -- Blank lines get commented too. Comment.nvim was configured with
  -- `ignore = '^$'` and skipped them; core has no such option, and losing it
  -- was an accepted cost of the swap, so pin the behaviour rather than
  -- discovering it in a diff later.
  eq(lines(0, 3), { '<!-- # Title -->', '<!---->', '<!-- Some prose here. -->' })
end

T['gc']['works as an operator over a visual selection'] = function()
  child.cmd([[normal 6GVjgc]])
  eq(lines(5, 7), { '-- local x = 1', '-- local y = 2' })
end

T['gc']['is toggled by the editor-style shortcut'] = function()
  -- <c-_> is what a terminal sends for Ctrl+/; the GUI branch maps <c-/>.
  -- Only the mapping is asserted, not the keypress: which of the two exists
  -- depends on the target the child booted into.
  local terminal = child.lua_get([[vim.fn.maparg('<c-_>', 'n')]])
  local gui = child.lua_get([[vim.fn.maparg('<c-/>', 'n')]])
  eq(terminal ~= '' or gui ~= '', true)
  eq((terminal ~= '' and terminal or gui), 'gcc')
end

T['gc']['is provided by Neovim, not by a plugin'] = function()
  local plugins = child.lua_get([[
        (function()
          local names = {}
          for name in pairs(require('lazy.core.config').plugins) do
            names[name] = true
          end
          return { comment = names['Comment.nvim'] or false,
                   tscs = names['nvim-ts-context-commentstring'] or false }
        end)()]])
  eq(plugins.comment, false)
  eq(plugins.tscs, false)
end

return T
