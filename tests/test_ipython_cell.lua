local H = require('helpers')
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T, child = H.new_unit_test()

--stylua: ignore start
local load_module = function(name) child.lua(([[_G.M = require(...)]]), { name }) end
local set_lines = function(lines) child.api.nvim_buf_set_lines(0, 0, -1, true, lines) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Both line and col is 1-based, inclusive range [from, to]
-- Set to to nil to represent empty region
local function region(from_line, from_col, to_line, to_col)
    local r = {
        from = {
            line = from_line,
            col = from_col,
        },
    }
    if to_line and to_col then
        r.to = {
            line = to_line,
            col = to_col,
        }
    end
    return r
end

local function gen_cases(lines, modes_and_expect)
    local cases = {}
    return vim.tbl_map(function(case)
        return { lines, unpack(case) }
    end, modes_and_expect)
end

local function concat_cases(...)
    local arg = {...}
    local t = {}

    for i = 1, #arg do
        local array = arg[i]
        if (type(array) == "table") then
            for j = 1, #array do
                t[#t+1] = array[j]
            end
        else
            t[#t+1] = array
        end
    end

    return t
end

T['edge_cases'] = new_set({
    parametrize = concat_cases(
        gen_cases({
            ' ',
            'aaa',
            'bbb',
            ' ',
            'ccc'
        }, {
            {'a', 'h', region(1, 1), region(1, 1, 5, 3) },
            {'a', 'H', region(1, 1), region(1, 1, 5, 3) },
            {'i', 'h', region(1, 1), region(2, 1, 5, 3) },
            {'i', 'H', region(1, 1), region(1, 1, 5, 3) },
        }),
        gen_cases({
            '# %%',
            ' ',
            'aaa',
            'bbb',
            ' ',
            'ccc',
            ' ',
            '# %%',
        }, {
            {'a', 'h', region(1, 1), region(1, 1, 6, 3) },
            {'a', 'H', region(1, 1), region(1, 1, 7, 1) },
            {'i', 'h', region(1, 1), region(3, 1, 6, 3) },
            {'i', 'H', region(1, 1), region(2, 1, 7, 1) },
            -- the last cell has no content
            {'a', 'h', region(8, 2), region(8, 1, 8, 4) },
            {'a', 'H', region(8, 2), region(8, 1, 8, 4) },
            {'i', 'h', region(8, 2), vim.NIL },
            {'i', 'H', region(8, 2), vim.NIL },
        }),
        gen_cases({
            '# %%',
            'abc',
        }, {
            {'a', 'h', region(1, 1), region(1, 1, 2, 3)},
            {'a', 'H', region(1, 1), region(1, 1, 2, 3)},
            {'i', 'h', region(2, 1), region(2, 1, 2, 3)},
            {'i', 'H', region(2, 1), region(2, 1, 2, 3)},
        }),
        gen_cases({
            '# %%',
            '   ',
        }, {
            {'a', 'h', region(1, 1), region(1, 1, 1, 4)},
            {'a', 'H', region(1, 1), region(1, 1, 2, 3)},
            {'i', 'h', region(2, 1), vim.NIL},
            {'i', 'H', region(2, 1), region(2, 1, 2, 3)},
        })
    )
})

T['edge_cases']['works'] = function(lines, aitype, id, ref, expected)
    load_module('ucw.textobjects.ipython')
    set_lines(lines)

    local region = child.lua_get([[M.cell(...)]], { aitype, id, { reference_region = ref }})
    eq(region, expected)
end

return T
