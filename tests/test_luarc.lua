-- `.luarc.json` and `after/lsp/lua_ls.lua` both configure lua_ls, and they are
-- *different scopes on purpose*: the checked-in `.luarc.json` applies to this
-- repo only (and is what `just lint` and the CI `lint` job read), while
-- `after/lsp/lua_ls.lua` is this config's global lua_ls setup and follows the
-- user into every other Lua project they open. Neither can own the other.
--
-- What they can do is drift, and the direction that hurts is one-way: a global
-- known to this config but missing from `.luarc.json` means the gate reports an
-- `undefined-global` that the editor never showed, i.e. CI red on code that
-- looked clean while it was written. The reverse (extra globals here) is fine -
-- this repo genuinely has some the general case does not.
--
-- So: superset, not equality. This is the cheap version of the "one writer"
-- rule Phase 3 settled on for `client.settings`, applied where a single writer
-- is not available. See docs/design/phase7-ci.md §3.3.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_unit_test()

local function read_json(path)
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
  eq({ path, ok }, { path, true })
  return decoded
end

T['.luarc.json'] = new_set()

T['.luarc.json']['covers every global after/lsp/lua_ls.lua declares'] = function()
  local luarc = read_json('.luarc.json')
  local from_luarc = luarc.diagnostics and luarc.diagnostics.globals or {}

  -- Loaded rather than pattern-matched, so a global added inside a conditional
  -- or built from a variable still counts.
  local from_lsp = child.lua_get([[
    (function()
      local conf = dofile('after/lsp/lua_ls.lua')
      return conf.settings.Lua.diagnostics.globals
    end)()
  ]])

  eq(#from_lsp > 0, true)

  local missing = {}
  for _, name in ipairs(from_lsp) do
    if not vim.tbl_contains(from_luarc, name) then
      table.insert(missing, name)
    end
  end
  table.sort(missing)
  eq(table.concat(missing, ', '), '')
end

-- The two settings docs/design/phase7-ci.md §1.5b found the hard way, after a
-- lint run that looked healthy and was quietly checking something else. They
-- are load-bearing together and only together: an explicit `runtime.path`
-- carrying `lua/?.lua` *without* `pathStrict` is measurably worse than neither,
-- because `require('snacks')` then resolves to this repo's own
-- `lua/ucw/plugins/snacks.lua` - one file per plugin, named after the plugin,
-- the config's oldest convention. Three real findings disappear and one false
-- positive appears, and the run still looks like a working lint gate.
T['.luarc.json']['keeps pathStrict on wherever runtime.path names lua/'] = function()
  local runtime = read_json('.luarc.json').runtime or {}
  local names_lua_dir = false
  for _, pattern in ipairs(runtime.path or {}) do
    if pattern:match('^lua/') then
      names_lua_dir = true
    end
  end
  eq({ names_lua_dir, runtime.pathStrict }, { true, true })
end

return T
