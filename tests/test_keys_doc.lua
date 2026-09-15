-- `docs/keys.md`'s tables are generated (`just keys-doc`, scripts/keys-doc.lua)
-- and checked in, so the key reference cannot drift from the config without
-- this going red - the same gate `lazy-lock.json` has in CI. The comparison
-- is byte-for-byte against a fresh render inside a booted child, which is
-- also the only assertion here: the generator's own correctness (baseline
-- subtraction, which-key labels) is visible in the rendered document.
local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

T['docs/keys.md'] = new_set()

T['docs/keys.md']['matches a fresh render of the global keymaps'] = function()
  local rendered = child.lua_get([[
        (function()
          vim.g.ucw_keys_doc_path = nil
          return dofile('scripts/keys-doc.lua')
        end)()
    ]])
  local lines = vim.fn.readfile('docs/keys.md')
  local begin_at, end_at
  for i, l in ipairs(lines) do
    if l == '<!-- keys-doc:begin -->' then
      begin_at = i
    elseif l == '<!-- keys-doc:end -->' then
      end_at = i
    end
  end
  eq({ begin_at ~= nil, end_at ~= nil }, { true, true })
  local checked_in = table.concat(vim.list_slice(lines, begin_at + 1, end_at - 1), '\n')
  -- a diff-shaped failure message: the first differing line, not two blobs
  local a, b = vim.split(checked_in, '\n'), vim.split(rendered, '\n')
  for i = 1, math.max(#a, #b) do
    if a[i] ~= b[i] then
      eq(
        { line = i, checked_in = a[i], rendered = b[i], hint = 'run `just keys-doc`' },
        { line = i, checked_in = b[i], rendered = b[i], hint = 'run `just keys-doc`' }
      )
    end
  end
  eq(#a, #b)
end

return T
