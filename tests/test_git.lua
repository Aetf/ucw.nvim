-- `ucw.git`: the seam that lets `<CR>` in a neogit buffer open codediff while
-- every other row in that buffer keeps doing what neogit does with it.
--
-- Driven through a real `:Neogit` on a throwaway repository rather than
-- asserted against neogit's source, because both halves of this are exactly
-- the kind of thing that reads correct and is not:
--
--   * the override has to be installed *after* neogit's own mapping.
--     `lib/buffer.lua` sets the filetype, then the mappings, then shows the
--     window, so a `FileType` hook loses - measured, silently, the override
--     had no effect at all and `<CR>` still opened the commit view.
--   * the divert has to fire on commit rows *only*. The status buffer's file
--     rows carry a `yankable` too (their filename), so "is there a yankable"
--     alone would send `<CR>` on a modified file to `git rev-parse` instead of
--     opening it.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- A two-commit repo with one modified file, so the status buffer has a commit
-- row and a file row to aim at. Built in the parent: the child only needs to
-- `tcd` into it.
local function make_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  local function git(...)
    local cmd = { 'git', '-C', dir, '-c', 'user.email=t@t', '-c', 'user.name=t', ... }
    local res = vim.system(cmd, { text = true }):wait()
    assert(res.code == 0, table.concat(cmd, ' ') .. ' -> ' .. tostring(res.stderr))
  end
  git('init', '-q')
  vim.fn.writefile({ 'one', 'two', 'three' }, dir .. '/a.txt')
  git('add', 'a.txt')
  git('commit', '-qm', 'first commit\n\nA body that is not the subject.')
  vim.fn.writefile({ 'one', 'CHANGED', 'three' }, dir .. '/a.txt')
  git('commit', '-qam', 'second commit')
  vim.fn.writefile({ 'one', 'CHANGED', 'three', 'four' }, dir .. '/a.txt')
  return dir
end

-- `:Neogit` is async all the way down (plenary coroutines around `git`), and
-- there is no event to hang this on - so poll the one condition that means it
-- is up, rather than guessing a duration.
--
-- The condition has to be a *loaded* status buffer, not a present one: neogit
-- paints a skeleton first (`Head: 0000000 (no commits)`, four lines) and fills
-- it in when the git calls come back. Waiting on the filetype and a line count
-- caught that skeleton, and every case then asserted against an empty
-- repository - green helper, meaningless test.
local function open_neogit(dir)
  child.lua(([[vim.cmd('tcd %s')]]):format(dir))
  child.lua([[vim.cmd('Neogit')]])
  local ok = child.lua_get([[
        vim.wait(20000, function()
          if vim.bo.filetype ~= 'NeogitStatus' then return false end
          for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
            if l:match('^Recent Commits') then return true end
          end
          return false
        end, 50)
    ]])
  eq(ok, true)
end

---Line number of the first buffer line matching `pat`, asserted to exist.
local function line_of(pat)
  local lnum = child.lua_get(([[
        (function()
          for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
            if l:match(%q) then return i end
          end
          return 0
        end)()
    ]]):format(pat))
  if lnum == 0 then
    -- the whole buffer in the failure message: a status buffer that is not
    -- what the case assumed is the failure mode worth naming precisely
    eq(
      { pat, child.lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), ' | ')]]) },
      { pat, 'a line matching the pattern' }
    )
  end
  return lnum
end

T['neogit <CR>'] = new_set()

T['neogit <CR>']['is wrapped once neogit has bound its own'] = function()
  local dir = make_repo()
  open_neogit(dir)
  eq(child.lua_get([[vim.fn.maparg('<CR>', 'n', false, true).desc]]), 'Diff this commit (codediff)')
  -- and buffer-local, so `<CR>` is untouched everywhere else
  eq(child.lua_get([[vim.fn.maparg('<CR>', 'n', false, true).buffer]]), 1)
  vim.fn.delete(dir, 'rf')
end

-- The half the user asked for and the half that must not break, in one case:
-- a commit row resolves to an oid, every other row resolves to nothing and so
-- falls through to neogit.
T['neogit <CR>']['diverts on commit rows and only on commit rows'] = function()
  local dir = make_repo()
  open_neogit(dir)

  local function ref_at(lnum)
    return child.lua_get(([[
          (function()
            vim.api.nvim_win_set_cursor(0, { %d, 0 })
            return require('ucw.git').commit_under_cursor() or false
          end)()
      ]]):format(lnum))
  end

  -- `Head:` and the entries under `Recent Commits` are commits
  local head = ref_at(line_of('^Head:'))
  eq(type(head) == 'string' and head:match('^%x+$') ~= nil, true)

  -- so is a row under `Recent Commits`
  eq(ref_at(line_of('^Recent Commits') + 1) ~= false, true)

  -- the modified file is not, even though its row carries a `yankable`
  eq(ref_at(line_of('^modified')), false)

  -- neither is the hint line or a section header
  eq(ref_at(line_of('^Unstaged changes')), false)

  vim.fn.delete(dir, 'rf')
end

-- The fallback really is neogit's, not a stub: `<CR>` on the file row still
-- opens that file. Driven through `:normal` so the wrapper, not the helper, is
-- what runs.
T['neogit <CR>']['still opens the file on a file row'] = function()
  local dir = make_repo()
  open_neogit(dir)

  child.lua(([[vim.api.nvim_win_set_cursor(0, { %d, 0 })]]):format(line_of('^modified')))
  child.lua([[
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'x', false)
    ]])
  local opened = child.lua_get([[
        vim.wait(5000, function()
          return vim.fn.expand('%:t') == 'a.txt'
        end, 50)
    ]])
  eq(opened, true)

  vim.fn.delete(dir, 'rf')
end

T['commit message'] = new_set()

T['commit message']['<leader>gm is a live stub before codediff loads'] = function()
  eq(child.lua_get([[require('lazy.core.config').plugins['codediff.nvim']._.loaded ~= nil]]), false)
  eq(child.lua_get([[vim.fn.maparg(' gm', 'n', false, true).desc]]), 'Commit message for this diff')
end

T['commit message']['renders the full message for the commit under the cursor'] = function()
  local dir = make_repo()
  open_neogit(dir)

  child.lua(([[vim.api.nvim_win_set_cursor(0, { %d, 0 })]]):format(line_of('^Head:')))
  child.lua([[require('ucw.git').show_message()]])

  -- The body, not just the subject, is what the commit view used to be the
  -- only source of - so that is what is asserted.
  local win = child.lua_get([[
        (function()
          local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          return { ft = vim.bo.filetype, text = table.concat(lines, '\n') }
        end)()
    ]])
  eq(win.ft, 'git')
  eq(win.text:find('second commit', 1, true) ~= nil, true)
  eq(win.text:find('AuthorDate:', 1, true) ~= nil, true)

  vim.fn.delete(dir, 'rf')
end

T['commit message']['says so when there is no commit in sight'] = function()
  local warned = child.lua_get([[
        (function()
          vim.cmd('enew!')
          local msgs = {}
          local notify = vim.notify
          vim.notify = function(msg, level) table.insert(msgs, { msg = msg, level = level }) end
          require('ucw.git').show_message()
          vim.notify = notify
          return msgs
        end)()
    ]])
  eq(#warned, 1)
  eq(warned[1].msg:find('No commit here', 1, true) ~= nil, true)
  eq(warned[1].level, vim.log.levels.WARN)
end

return T
