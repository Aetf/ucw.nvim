local M = {}

local fmt = string.format


---@param should_profile boolean
---@return string
local profile_time = function(should_profile)
  return fmt(
    [[
  local time
  _G.profile_info = {}
  local should_profile = %s
  if should_profile then
    local hrtime = vim.loop.hrtime
    _G.profile_info = {}
    time = function(chunk, start)
      if start then
        profile_info[chunk] = hrtime()
      else
        profile_info[chunk] = (hrtime() - profile_info[chunk]) / 1e6
      end
    end
  else
    time = function(chunk, start) end
  end
  ]],
    vim.inspect(should_profile)
  )
end

local profile_output = [[
local function save_profiles()
  local sorted_times = {}
  for chunk_name, time_taken in pairs(_G.profile_info) do
    sorted_times[#sorted_times + 1] = {chunk_name, time_taken}
  end
  table.sort(sorted_times, function(a, b) return a[2] > b[2] end)
  local results = {}
  for i, elem in ipairs(sorted_times) do
    results[i] = elem[1] .. ' took ' .. elem[2] .. 'ms'
  end
  _G._profile_output = results
end
]]

function M.prepare(should_profile)
  local compiled = {}

  table.insert(compiled, profile_time(should_profile))
  table.insert(compiled, profile_output)
  return compiled
end

return M
