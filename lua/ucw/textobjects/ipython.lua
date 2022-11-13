local M = {}

-- Find the previous and next mark, return 1-base line number.
-- If prev not exist, set prev to 0
-- If cursor_line is on mark, do not move
local function locate_prev(cursor_line, mark)
  local prev = cursor_line
  while prev >= 1 do
    local line = vim.fn.getline(prev)
    if line:match(mark) then
      break
    end
    prev = prev - 1
  end
  return prev
end

-- Find the previous and next mark, return 1-base line number.
-- If next not exist, set next to max+1
-- If cursor_line is on mark, do not move
local function locate_next(cursor_line, mark)
  local max_line = vim.api.nvim_buf_line_count(0)
  local next = cursor_line + 1
  while next <= max_line do
    local line = vim.fn.getline(next)
    if line:match(mark) then
      break
    end
    next = next + 1
  end

  return next
end

-- construct region based on request
--          from -> # %%
--                  .....
-- content_start -> code
--                  code
--   content_end -> code
--                  .....
--          next -> # %%
local function cell2region(cell, max_line, ai_type, id)
  if cell.from == cell.next then
    return nil
  end

  local new_region = function(from ,to)
    if to == nil or from == nil then
      return nil
    end
    -- empty, has to be done before clamping to valid range
    if to < from then
      return nil
    end
    -- clamp to valid range
    from = math.max(1, math.min(from, max_line))
    to = math.max(1, math.min(to, max_line))
    return {
      from = { line = from, col = 1 },
      to = { line = to, col = vim.fn.getline(to):len() },
    }
  end

  local regions = {
    ah = new_region(cell.from, cell.content_end or (cell.next - 1)),
    aH = new_region(cell.from, cell.next - 1),
    ih = new_region(cell.content_start, cell.content_end),
    iH = new_region(cell.from + 1, cell.next - 1),
  }
  return regions[ai_type .. id]
end

-- pattern for ipython cells
-- a selects with leading `# %%` comment, while i doesn't.
-- for textobject `h`, no edge empty lines,
-- for textobject `H`, include all lines
function M.cell(ai_type, id, opts)
  local mark = '^# ?%%%%%s*$'

  local max_line = vim.api.nvim_buf_line_count(0)
  local n_times = opts.n_times or 1
  -- refine maximum range we care
  -- first move to left edge
  local range_start = locate_prev(opts.reference_region.from.line, mark)
  local range_end = locate_next(opts.reference_region.from.line, mark)
  local count = 0
  while count < n_times and range_start > 1 do
    range_start = locate_prev(range_start - 1, mark)
    count = count + 1
  end
  count = 0
  while count < n_times and range_end < max_line do
    range_end = locate_next(range_end + 1, mark)
    count = count + 1
  end

  -- range_start can be 0
  -- range_end can be max_line + 1
  local res = {}
  local cell = {
    from = range_start,
    content_start = nil,
    content_end = nil,
    next = nil,
  }
  -- STATE:
  -- * MK (last line is mark)
  -- * HWS (last line is whitespace (no content yet))
  -- * TWS (last line is whitespace (seen content))
  -- * CT (last line is content)
  local state = 'MK'

  local finish_cell = function(ln)
    cell.next = ln
    if state == 'HWS' then
      cell.content_end = cell.from
    end
    table.insert(res, cell)
    return {
      from = ln,
      content_start = nil,
      content_end = nil,
      next = nil,
    }
  end

  -- look at lines using the actual valid ln
  for ln = math.max(1, range_start), math.min(max_line, range_end) do
    local line = vim.fn.getline(ln)
    -- check next state
    local next_state = nil
    if line:match(mark) then
      next_state = 'MK'
    elseif line:match('^%s*$') then
      next_state = ({
        MK = 'HWS',
        HWS = 'HWS',
        TWS = 'TWS',
        CT = 'TWS',
      })[state]
    else
      next_state = 'CT'
    end

    if next_state == 'MK' then
      cell = finish_cell(ln)
    end
    if next_state == 'CT' and (state == 'MK' or state == 'HWS') then
      cell.content_start = ln
      cell.content_end = ln
    end
    if next_state == 'CT' and (state == 'CT' or state == 'TWS') then
      cell.content_end = ln
    end

    -- transite to that state
    state = next_state
  end
  -- finish last cell
  finish_cell(range_end)

  -- map cell to requested region
  local regions = vim.tbl_filter(
    function(region) return region ~= nil end,
    vim.tbl_map(function(cell)
      return cell2region(cell, max_line, ai_type, id)
    end, res)
  )

  return regions
end

return M
