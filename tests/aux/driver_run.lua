-- process the global test tags, which is space separated tags
local tags = vim.split(vim.g.TestTags, ' ', { plain = true, trimempty = true })

-- filter test case by tags
local function has_tags(tags)
  return function(case)
    local case_tags = {}
    for _, tag in ipairs((case.data or {}).tags or {}) do
      case_tags[tag] = true
    end
    for _, tag in ipairs(tags) do
      if not case_tags[tag] then
        return false
      end
    end
    return true
  end
end


MiniTest.run{
  collect = {
    filter_cases = has_tags(tags),
  },
  execute = {
    stop_on_error = vim.g.TestExecuteStopOnError,
  },
}
