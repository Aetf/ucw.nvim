-- disable hard wrap
vim.opt_local.textwidth = 0
vim.opt_local.wrap = true

local function contains_latex_comment(line)
  -- backslash literal                             \\
  -- previous atom not match (looking back 1 byte) \@1<!
  -- percent literal                               %
  local ptn = vim.regex [[\\\@1<!%]]
  if ptn:match_str(line) then
    return true
  else
    return false
  end
end

-- chunk length if concatenated
local function chunk_len(chunk)
  local len = 0
  for _, line in pairs(chunk[1]) do
    len = len + string.len(line)
  end
  -- when concatenated, there is one space in between each line
  len = len + #chunk[1] - 1
  return len
end

-- append a line to the chunk,
-- return trimmed line
local function chunk_add_line(chunk, line, is_comment)
  local trimmed_indent = 0
  if not is_comment then
    -- normal lines are trimmed before adding to chunk
    if not vim.tbl_isempty(chunk[1]) then
      -- first line's whitespace at beginning is kept as indentation
      trimmed_indent = string.len(line)
      line = line:gsub("^%s+", "")
      trimmed_indent = trimmed_indent - string.len(line)
    end
    line = line:gsub("%s+$", "")
  end
  table.insert(chunk[1], line)
  return trimmed_indent, line
end

-- one sentence per line formatting
-- Note that cursor position restoration doesn't work, as text object messes with that already.
local function latexformatexpr_restore(lnum, count)
  if vim.tbl_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    -- `formatexpr` is also called when exceeding `textwidth` in insert mode
    -- fall back to internal formatting
    return 1
  end
  local start_line = lnum
  local end_line = start_line + count

  local pos = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line - 1, true)

  -- split lines into chunks, each chunk is either normal lines, or a line containing comment (%)
  -- comment lines are skipped from formatting and kept as is.
  local chunks = {}
  local chunk = {{}, false, nil} -- {lines, is_comment, [cursor_col]} cursor_col is 0-based byte-index into the string
  for idx, line in ipairs(lines) do
    local is_comment = contains_latex_comment(line)
    if is_comment ~= chunk[2] then
      if not vim.tbl_isempty(chunk[1]) then
        table.insert(chunks, chunk)
      end
      chunk = {{}, is_comment, nil}
    end
    -- this chunk should contain cursor
    if start_line + idx - 1 == pos[1] then
      local orig_len = chunk_len(chunk)
      local trimmed_indent, trimmed_line = chunk_add_line(chunk, line)
      chunk[3] = orig_len + 1    - trimmed_indent + pos[2]
      --         ^          ^      ^                ^
      --         existing  <SPC>   removed          current cursor col

      -- make sure cursor doesn't go beyond current line
      local new_len = orig_len + 1 + string.len(trimmed_line)
      if chunk[3] >= new_len then
        chunk[3] = new_len - 1
      end
    else
      chunk_add_line(chunk, line)
    end
  end
  if not vim.tbl_isempty(chunk[1]) then
    table.insert(chunks, chunk)
  end

  local need_cursor_update = false
  local new_pos = {}

  local replacement = {}
  local pattern = [[[.!?:;]\zs\s\ze\S\|\.\\@\zs\s\ze\S]]
  for _, chunk in ipairs(chunks) do
    if chunk[2] then
      -- is comment, keep as is
      for _, line in ipairs(chunk[1]) do
        table.insert(replacement, line)
      end
    else
      -- join all lines
      local line = table.concat(chunk[1], " ")
      if chunk[3] == nil then
        -- end of sentence:
        --   either a single char [.!?:;]
        --   or                   \|
        --   a senquence          \.\\@
        -- and they must followed by
        --   one space     \zs\s\ze\S
        -- there will be exactly one space because the line is joined from trimmed buffer lines
        line = vim.fn.substitute(line, pattern, [[\r]], "g")
        local new_lines = vim.fn.split(line, [[\r]])
        for _, line in ipairs(new_lines) do
          table.insert(replacement, line)
        end
      else
        -- special handling when the chunk contains cursor
        need_cursor_update = true
        new_pos = { start_line + #replacement, chunk[3] }

        while true do
          if string.len(line) == 0 then
            break
          end
          -- s, e are 0-based, [s, e)
          local _, s, e = unpack(vim.fn.matchstrpos(line, pattern))
          if s == -1 then
            table.insert(replacement, line)
            break
          end
          local part = string.sub(line, 1, s) -- string.sub is 1-based
          line = string.sub(line, e + 1)
          if string.len(part) > 0 then
            table.insert(replacement, part)
            if new_pos[2] >= e then
              new_pos[1] = new_pos[1] + 1
              new_pos[2] = new_pos[2] - e
            end
          end
        end
      end
    end
  end

  -- update lines in buffer
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line - 1, true, replacement)

  -- try to restore cursor position
  if need_cursor_update then
    vim.api.nvim_win_set_curosr(0, new_pos)
  end

  -- do not run builtin formatter
  return 0
end

local function latexformatexpr(lnum, count)
  if vim.tbl_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    -- `formatexpr` is also called when exceeding `textwidth` in insert mode
    -- fall back to internal formatting
    return 1
  end
  local start_line = lnum
  local end_line = start_line + count

  local pos = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line - 1, true)

  -- split lines into chunks, each chunk is either normal lines, or a line containing comment (%)
  -- comment lines are skipped from formatting and kept as is.
  local chunks = {}
  local chunk = {{}, false} -- {lines, is_comment}
  for idx, line in ipairs(lines) do
    local is_comment = contains_latex_comment(line)
    if is_comment ~= chunk[2] then
      if not vim.tbl_isempty(chunk[1]) then
        table.insert(chunks, chunk)
      end
      chunk = {{}, is_comment}
    end
    chunk_add_line(chunk, line)
  end
  if not vim.tbl_isempty(chunk[1]) then
    table.insert(chunks, chunk)
  end

  local replacement = {}
  local pattern = [[[.!?:;]\zs\s\ze\S\|\.\\@\zs\s\ze\S]]
  for _, chunk in ipairs(chunks) do
    if chunk[2] then
      -- is comment, keep as is
      for _, line in ipairs(chunk[1]) do
        table.insert(replacement, line)
      end
    else
      -- join all lines
      local line = table.concat(chunk[1], " ")
      -- end of sentence:
      --   either a single char [.!?:;]
      --   or                   \|
      --   a senquence          \.\\@
      -- and they must followed by
      --   one space     \zs\s\ze\S
      -- there will be exactly one space because the line is joined from trimmed buffer lines
      line = vim.fn.substitute(line, pattern, [[\r]], "g")
      local new_lines = vim.fn.split(line, [[\r]])
      for _, line in ipairs(new_lines) do
        table.insert(replacement, line)
      end
    end
  end

  -- update lines in buffer
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line - 1, true, replacement)

  -- do not run builtin formatter
  return 0
end

function safe_latex_format_expr(lnum, count)
  local good, res = pcall(latexformatexpr, lnum, count)
  if not good then
    vim.notify(res)
    res = 0
  end
  return res
end
vim.opt_local.formatexpr = 'v:lua.safe_latex_format_expr(v:lnum, v:count)'
