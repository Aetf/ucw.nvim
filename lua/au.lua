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

    -- action can be a function or string
    local action = is_table and spec[2] or spec
    if type(action) == 'function' then
        action = this.set(action)
    end

    -- event can be a table or string
    local e = type(event) == 'table' and table.concat(event, ',') or event

    -- once if present, translates to ++once
    local once = is_table and spec.once or false
    once = once and '++once' or ''

    -- nested if present, translates to ++nested
    local nested = is_table and spec.nested or false
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

function S.exec(id)
    S.__au[id]()
end

function S.set(fn)
    local id = string.format('%p', fn)
    S.__au[id] = fn
    return string.format('lua require("au").exec("%s")', id)
end

function S.group(grp, cmds)
    cmd('augroup ' .. grp)
    cmd('autocmd!')
    if type(cmds) == 'function' then
        cmds(X)
    else
        for _, au in ipairs(cmds) do
            local ptn = table.remove(au, 1)
            autocmd(S, ptn, au)
        end
    end
    cmd('augroup END')
end

return X
