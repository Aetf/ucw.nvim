-- Coverage for `ucw.utils`' own behaviour, as opposed to the features built on
-- it: right now the jumplist landing rule, which two unrelated things read.
--
-- The founding bug: `getjumplist()` returns `{list, idx}` together, and
-- `win_backward_buf` indexed that pair twice - once to take the list, then
-- again as if it were still the pair. What it called the jumplist was a single
-- jump entry, so `#jumplist` was 0 and the function returned nothing for every
-- window that had one. It is not dead code (`bufdelete` picks the buffer to
-- show after closing one with it, and `ucw.keys.actions.jump_file` steps
-- through files with it), it simply never answered, and both callers have a
-- fallback that looks like a deliberate choice from the outside.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_unit_test()

T['jumplist landing'] = new_set()

-- Three files so a count has somewhere to go, and so "different buffer" is
-- distinguishable from "the one before".
local function build_jumplist()
  local files, names = {}, {}
  for i = 1, 3 do
    files[i] = vim.fn.tempname() .. '.txt'
    names[i] = vim.fn.fnamemodify(files[i], ':t')
    local lines = {}
    for n = 1, 20 do
      lines[n] = 'line ' .. n
    end
    vim.fn.writefile(lines, files[i])
  end

  -- jumplist: f1:1 f1:5 f1:15 | f2:1 f2:4 f2:12 | f3:1, cursor at f3:7
  child.cmd('edit ' .. files[1])
  child.cmd('clearjumps')
  child.cmd('normal! 5G')
  child.cmd('normal! 15G')
  child.cmd('edit ' .. files[2])
  child.cmd('normal! 4G')
  child.cmd('normal! 12G')
  child.cmd('edit ' .. files[3])
  child.cmd('normal! 7G')

  return files, names
end

local function landing(dir, count)
  return child.lua_get(([[
      (function()
        local steps, buf = require('ucw.utils').win_jump_other_buf(0, nil, %d, %d)
        if steps == nil then return 'none' end
        return { steps, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t') }
      end)()
    ]]):format(dir, count))
end

-- The step count is what the caller hands to `<C-o>`, so it is asserted
-- alongside the buffer: a right buffer reached by the wrong number of presses
-- lands somewhere else entirely.
T['jumplist landing']['skips entries in the current file, and counts the presses'] = function()
  local files, names = build_jumplist()

  -- two entries back is where f2 starts, not one (f3:1 is the same file)
  eq(landing(-1, 1), { 2, names[2] })
  eq(landing(-1, 2), { 5, names[1] })
  eq(landing(1, 1), 'none')

  for _, path in ipairs(files) do
    vim.fn.delete(path)
  end
end

-- The wrapper `bufdelete` uses. Asserted through the public entry point rather
-- than the local, because that is the path the bug was invisible on.
T['jumplist landing']['bufdelete falls back to the jumplist, not the buffer list'] = function()
  local files, names = build_jumplist()

  -- an unrelated buffer that `bnext` would reach first, to tell the jumplist
  -- preference apart from the plain "some other buffer" fallback
  child.cmd('badd ' .. files[1] .. '.decoy')
  child.lua([[require('ucw.utils').bufdelete(0, true)]])
  eq(child.lua_get([[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')]]), names[2])

  for _, path in ipairs(files) do
    vim.fn.delete(path)
  end
end

return T
