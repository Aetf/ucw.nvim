-- One generic guard against a mistake this config has now made twice, both
-- times in a commit that was fixing something else: calling a Neovim API that
-- upstream has already scheduled for removal.
--
--   * `vim.diagnostic.goto_next`/`goto_prev` sat behind `g[`/`g]` for a month
--     (Phase 3 acceptance review, P3). Nobody saw the warning because the keys
--     were not actually mapped, so the line never ran.
--   * `vim.lsp.get_buffers_by_client_id()` was introduced *by the commit that
--     fixed P3*, in the LspDetach handler it added. That one did print, on every
--     `:bdelete` of a buffer with a client - but into `:messages`, where a
--     warning is one line among many (second-round review, Q1).
--
-- Neither is the kind of thing a behavioural test catches: the code works,
-- right up until the release that removes it. So this asserts the *shape*
-- instead, the way tests/test_keys.lua asserts that no which-key `desc` looks
-- like a right-hand side.
--
-- The list of deprecated names is not hard-coded - it is read out of the
-- runtime of whatever Neovim runs the suite, so it tracks upstream by itself.
-- Only calls count; mentioning a name in a comment is how the ones already
-- dealt with are documented.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

-- Every `vim.deprecate('<name>', ...)` in the running Neovim's own runtime.
local INSTALL_SCANNER = [[
  function _G.__deprecated_names()
    local names, seen = {}, {}
    local runtime = vim.env.VIMRUNTIME .. '/lua/vim'
    for path, kind in vim.fs.dir(runtime, { depth = 4 }) do
      if kind == 'file' and path:match('%.lua$') then
        local src = table.concat(vim.fn.readfile(runtime .. '/' .. path), '\n')
        -- the name can sit on the line after the call opens, since these get
        -- wrapped when the replacement string is long
        for name in src:gmatch("vim%.deprecate%(%s*'([^']+)'") do
          -- upstream spells these both ways: `vim.lsp.stop_client()` and
          -- `vim.diagnostic.goto_next()` carry the parens, `vim.tbl_flatten`
          -- does not
          name = name:gsub('%(%)$', '')
          if name:match('^vim%.[%w_.]+$') and not seen[name] then
            seen[name] = true
            table.insert(names, name)
          end
        end
      end
    end
    table.sort(names)
    return names
  end
]]

local child
local T
T, child = H.new_unit_test {
  hooks = {
    pre_case = function()
      child.lua(INSTALL_SCANNER)
    end,
  },
}

T['deprecated APIs'] = new_set()

-- Guards the guard: if the scan silently stops finding anything - upstream
-- changes how it spells deprecations, say - the assertion below would pass
-- vacuously forever.
T['deprecated APIs']['the runtime scan finds something to check against'] = function()
  local names = child.lua_get([[_G.__deprecated_names()]])
  eq(#names > 10, true)
  eq(vim.tbl_contains(names, 'vim.lsp.get_buffers_by_client_id'), true)
  eq(vim.tbl_contains(names, 'vim.diagnostic.goto_next'), true)
end

T['deprecated APIs']['nothing in this config calls one'] = function()
  local offenders = child.lua_get([[
        (function()
          local names = _G.__deprecated_names()
          local files = vim.fn.glob('*.lua', false, true)
          for _, root in ipairs({ 'lua', 'after', 'ftplugin' }) do
            vim.list_extend(files, vim.fn.glob(root .. '/**/*.lua', false, true))
          end

          local bad = {}
          for _, path in ipairs(files) do
            local lnum = 0
            for _, line in ipairs(vim.fn.readfile(path)) do
              lnum = lnum + 1
              if not line:match('^%s*%-%-') then
                for _, name in ipairs(names) do
                  -- the `(` is what makes it a call rather than a mention
                  if line:find(vim.pesc(name) .. '%s*%(') then
                    table.insert(bad, ('%s:%d: %s'):format(path, lnum, name))
                  end
                end
              end
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  eq(offenders, {})
end

return T
