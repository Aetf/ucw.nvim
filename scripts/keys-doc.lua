-- Render the global keymaps this config defines as the markdown tables in
-- `docs/keys.md`, so the key reference is generated from a real boot rather
-- than maintained by hand. `just keys-doc` writes it; `tests/test_keys_doc.lua`
-- fails when the checked-in tables differ from a fresh render, the same way
-- CI fails on a drifted `lazy-lock.json`.
--
-- "This config defines" = present after boot and not identical (mode, lhs,
-- desc, rhs) to a mapping in `nvim --clean`, so Neovim's own defaults (`[b`,
-- `gcc`, `<C-W>d`, ...) are not listed and a default this config rebinds
-- (`grr`, `gO`) is. `<Plug>` mappings are plugin-internal and skipped. Buffer-local keys (LSP, python cells, neogit, help/quickfix) never
-- reach `nvim_get_keymap` and are the hand-written half of `docs/keys.md`.
--
-- Run inside a booted instance with which-key loaded (the `<leader>` group
-- labels come from its registry): see the `keys-doc` recipe in the justfile.
-- Set `vim.g.ucw_keys_doc_path` to write a file; otherwise the markdown is
-- returned from the chunk.

local MODES = { 'n', 'x', 's', 'o', 'i', 'c', 't' }

-- Every mapping a bare Neovim already has, as the same key `collect` uses.
local function identity(m)
  local rhs = type(m.callback) == 'function' and '' or (m.rhs or '')
  return table.concat({ m.mode, m.lhs, m.desc or '', rhs }, '\t')
end

local function baseline()
  local script = table.concat({
    'local out = {}',
    'for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t" }) do',
    '  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do',
    '    local rhs = type(m.callback) == "function" and "" or (m.rhs or "")',
    '    out[#out + 1] = table.concat({ m.mode, m.lhs, m.desc or "", rhs }, "\\t")',
    '  end',
    'end',
    'io.stdout:write(table.concat(out, "\\n"))',
  }, '\n')
  local res = vim.system({ vim.v.progpath, '--clean', '--headless', '-l', '-' }, { stdin = script, text = true }):wait()
  assert(res.code == 0, 'baseline nvim --clean failed: ' .. tostring(res.stderr))
  local set = {}
  for line in (res.stdout or ''):gmatch('[^\n]+') do
    set[line] = true
  end
  assert(next(set) ~= nil, 'baseline is empty')
  return set
end

-- `nvim_get_keymap('x')` also returns ' ' (n+v+o) and 'v' mappings; the
-- mapping's own `mode` field is what dedups it. Rows are keyed on lhs+desc
-- so one key bound identically in several modes is one row.
local function collect(base)
  local rows, order = {}, {}
  for _, query in ipairs(MODES) do
    for _, m in ipairs(vim.api.nvim_get_keymap(query)) do
      if not m.lhs:find('<Plug>', 1, true) and not base[identity(m)] then
        local desc = m.desc or ''
        local rhs = type(m.callback) == 'function' and '' or (m.rhs or '')
        local key = m.lhs .. '\t' .. desc .. '\t' .. rhs
        if not rows[key] then
          rows[key] = { lhs = m.lhs, desc = desc, rhs = rhs, modes = {} }
          order[#order + 1] = key
        end
        rows[key].modes[m.mode] = true
      end
    end
  end
  local out = {}
  for _, key in ipairs(order) do
    local r = rows[key]
    local modes = {}
    for _, mode in ipairs { ' ', 'n', 'v', 'x', 's', 'o', 'i', 'c', 't' } do
      if r.modes[mode] then
        modes[#modes + 1] = mode == ' ' and 'nvo' or mode
      end
    end
    r.mode = table.concat(modes, ' ')
    out[#out + 1] = r
  end
  return out
end

local function groups()
  local labels = {}
  local ok, Config = pcall(require, 'which-key.config')
  if ok then
    for _, m in ipairs(Config.mappings or {}) do
      -- `group` is set on header entries at runtime (measured; the display
      -- name is in `desc`) but absent from which-key's `wk.Spec` annotation
      ---@diagnostic disable-next-line: undefined-field
      if m.group and m.mode == 'n' and vim.startswith(m.lhs or '', '<leader>') then
        labels[m.lhs:sub(#'<leader>' + 1)] = m.desc
      end
    end
  end
  return labels
end

-- A code span for an lhs: a leading space is `<leader>`, a lone space is
-- `<Space>`, and a backtick inside the key needs the double-backtick form.
local function md(s)
  s = s:gsub('|', '\\|')
  if s:find('`', 1, true) then
    return '`` ' .. s .. ' ``'
  end
  return '`' .. s .. '`'
end

local function lhs_md(lhs)
  return md((lhs:gsub('^ ', '<leader>'):gsub(' ', '<Space>')))
end

local function table_for(rows)
  local lines = { '| key | mode | does |', '|---|---|---|' }
  table.sort(rows, function(a, b)
    if a.lhs ~= b.lhs then
      return a.lhs < b.lhs
    end
    return a.mode < b.mode
  end)
  for _, r in ipairs(rows) do
    local does = r.desc
    if does == '' then
      does = r.rhs ~= '' and ('→ ' .. md(r.rhs)) or '*(no description)*'
    end
    lines[#lines + 1] = ('| %s | %s | %s |'):format(lhs_md(r.lhs), r.mode, does)
  end
  return table.concat(lines, '\n')
end

local function render()
  -- which-key materialises its `wk.add` mappings and group registry from a
  -- callback scheduled on VimEnter; a `-c` command runs before that, so this
  -- is meant to run from a `VimEnter` autocmd (justfile) or a test body, and
  -- waits for the registry either way.
  local ok, Config = pcall(require, 'which-key.config')
  if ok then
    assert(
      vim.wait(5000, function()
        return Config.loaded == true
      end, 50),
      'which-key did not finish loading'
    )
  end
  local rows = collect(baseline())
  local labels = groups()

  -- `<leader>` rows bucket on the character after the leader; the bucket's
  -- heading is which-key's group label, or the leaf's own desc when the
  -- prefix is a single key (`<leader>l`, `<leader>n`).
  local leader, other = {}, {}
  for _, r in ipairs(rows) do
    if r.lhs:sub(1, 1) == ' ' and #r.lhs > 1 then
      local first = r.lhs:sub(2, 2)
      leader[first] = leader[first] or {}
      table.insert(leader[first], r)
    else
      table.insert(other, r)
    end
  end

  local out = {}
  local firsts = vim.tbl_keys(leader)
  table.sort(firsts)
  for _, first in ipairs(firsts) do
    local label = labels[first]
    if not label and #leader[first] == 1 then
      label = leader[first][1].desc
    end
    out[#out + 1] = ('### %s — %s'):format(lhs_md(' ' .. first), label or '')
    out[#out + 1] = ''
    out[#out + 1] = table_for(leader[first])
    out[#out + 1] = ''
  end

  local by_mode = { n = {}, x = {}, i = {}, c = {}, t = {}, o = {} }
  for _, r in ipairs(other) do
    local m = r.mode:match('^%S+')
    local bucket = (m == 'nvo' or m == 'n' or m == 'v') and 'n' or (m == 's' and 'x' or m)
    by_mode[bucket] = by_mode[bucket] or {}
    table.insert(by_mode[bucket], r)
  end
  for _, mode in ipairs { 'n', 'x', 'o', 'i', 'c', 't' } do
    if by_mode[mode] and #by_mode[mode] > 0 then
      local title = ({
        n = 'Normal mode (and the visual/operator twins of these keys)',
        x = 'Visual mode only',
        o = 'Operator-pending mode only',
        i = 'Insert mode',
        c = 'Command-line mode',
        t = 'Terminal mode',
      })[mode]
      out[#out + 1] = '### ' .. title
      out[#out + 1] = ''
      out[#out + 1] = table_for(by_mode[mode])
      out[#out + 1] = ''
    end
  end
  return table.concat(out, '\n')
end

local text = render()
if vim.g.ucw_keys_doc_path then
  local path = vim.g.ucw_keys_doc_path
  local lines = vim.fn.readfile(path)
  local begin_at, end_at
  for i, l in ipairs(lines) do
    if l == '<!-- keys-doc:begin -->' then
      begin_at = i
    elseif l == '<!-- keys-doc:end -->' then
      end_at = i
    end
  end
  assert(begin_at and end_at and begin_at < end_at, path .. ': keys-doc markers not found')
  local new = {}
  vim.list_extend(new, lines, 1, begin_at)
  vim.list_extend(new, vim.split(text, '\n'))
  vim.list_extend(new, lines, end_at, #lines)
  vim.fn.writefile(new, path)
  print(('keys-doc: %s rendered'):format(path))
end
return text
