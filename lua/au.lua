-- Neovim autocmd in lua
-- Usage:
-- 1. fire on every buffer
-- ```lua
-- local au = require('au')
-- au.TextYankPost = function() end
-- ```
--
-- 2. with patterns, which can also be given as a single string '*.txt,*.lua'
-- ```lua
-- local au = require('au')
-- au.BufEnter = {
--   {'*.txt', '*.lua'},
--   function() end,
-- }
-- ```
--
-- 3. for multiple events. The full signature:
--   au(events: table, cmd: string | fn | {pattern: string | table, action: string | fn})
-- Note that the action can be a string which is intepreated as ex command
-- ```lua
-- local au = require('au')
-- au({ 'BufNewFile', 'BufRead'}, {
--   {'.eslintrc', '*.json*'},
--   function() end,
--   once = false,
--   nested = false,
-- })
-- ```
--
-- 4. autocmd group: au.group(group: string, cmds: fn(au) | {event: string, pattern: string | table, action: string | fn})
-- ```lua
-- local au = require('au')
-- au.group('AGroupName', {
--   { 'BufWritePost', 'plugins.lua', 'source <afile> | PackerCompile' },
--   { 'User', 'CocJumpPlaceholder', function() end, },
-- })
-- ```
local cmd = vim.api.nvim_command

local function autocmd(this, event, spec)
    local is_table = type(spec) == 'table'
    -- pattern can be a table or a string
    local pattern = is_table and spec[1] or '*'
    pattern = type(pattern) == 'table' and table.concat(pattern, ',') or pattern

    -- once if present, translates to ++once
    local once = is_table and spec.once or false

    -- nested if present, translates to ++nested
    local nested = is_table and spec.nested or false

    -- action can be a function or string
    local action = is_table and spec[2] or spec
    if type(action) == 'function' then
        action = this.set(action, once)
    end

    -- event can be a table or string
    local e = type(event) == 'table' and table.concat(event, ',') or event

    once = once and '++once' or ''
    nested = nested and '++nested' or ''
    cmd(table.concat({'autocmd', e, pattern, once, nested, action}, ' '))
end

local S = {
    __au = {},
}

local X = setmetatable({}, {
    __index = S,
    __newindex = autocmd,
    __call = autocmd,
})

---@param id string
---@param once boolean
function S.exec(id, once)
    S.__au[id]()
    if once then
        S.__au[id] = nil
    end
end

---@param fn fun()
---@param once boolean
function S.set(fn, once)
    local id = string.format('%p', fn)
    S.__au[id] = fn
    return string.format('lua require("au").exec("%s", %s)', id, once)
end

function S.group(grp, cmds)
    cmd('augroup ' .. grp)
    cmd('autocmd!')
    if type(cmds) == 'function' then
        cmds(X)
    else
        for _, au in ipairs(cmds) do
            local evt = table.remove(au, 1)
            autocmd(S, evt, au)
        end
    end
    cmd('augroup END')
end

return X
