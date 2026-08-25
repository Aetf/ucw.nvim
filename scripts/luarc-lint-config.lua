-- Generate `.luarc.lint.json` from `.luarc.json` by appending the installed
-- plugins' `lua/` directories to `workspace.library`.
--
-- Run as `nvim --clean -l scripts/luarc-lint-config.lua <in> <out>`.
--
-- Why this exists at all (docs/design/phase7-ci.md §1.5a/§3.3): the plugin
-- library is the difference between a lint gate that finds 22 problems and one
-- that finds 16 and says nothing about the other 6 - and the weaker one looks
-- exactly like the working one. It cannot be checked in, because the two things
-- that would let it be do not work: `workspace.library` does not expand globs
-- (`<lazy>/*/lua` resolves to nothing), and pointing at the lazy root instead of
-- each plugin's `lua/` is the silently-weaker variant just described. So it is
-- enumerated here, per environment, and the result is a *derived artifact*
-- rather than a second config: this script appends to exactly one key, so no
-- rule can come to live in `.luarc.lint.json` by construction rather than by
-- promise. The editor gets the same strength by another route entirely
-- (lazydev.nvim, on demand - see `after/lsp/lua_ls.lua`).
--
-- Everything here fails loudly rather than degrading, for the same reason: a
-- lint gate that quietly checks less is worse than one that does not run.

local src, dst = _G.arg[1], _G.arg[2]
if not src or not dst then
  io.stderr:write('usage: nvim --clean -l scripts/luarc-lint-config.lua <in.json> <out.json>\n')
  os.exit(2)
end

local function die(msg)
  io.stderr:write('luarc-lint-config: ' .. msg .. '\n')
  os.exit(1)
end

local ok, conf = pcall(function()
  return vim.json.decode(table.concat(vim.fn.readfile(src), '\n'))
end)
if not ok or type(conf) ~= 'table' then
  die(('could not parse %s'):format(src))
end
if type(conf.workspace) ~= 'table' or type(conf.workspace.library) ~= 'table' then
  die(('%s has no workspace.library to extend'):format(src))
end

-- Mirrors `bootstrap_lazy()` in lua/ucw/init.lua, which is also lazy.nvim's own
-- default. Asked of `stdpath` rather than of lazy so this needs no plugin
-- loaded and no config booted; the existence check below is what turns the
-- duplication into a loud failure if the root ever moves.
local lazy_root = vim.fs.joinpath(vim.fn.stdpath('data'), 'lazy')
if vim.fn.isdirectory(lazy_root) == 0 then
  die(('no plugin root at %s - run `just plugins` (or fix this path if lazy.nvim moved its root)'):format(lazy_root))
end

-- Named from the lockfile, not globbed off the disk. `<root>/*/lua` also
-- matches plugins that were *removed from the spec* and left behind - lazy
-- only deletes them on `:Lazy clean`, which nothing here runs - and a library
-- entry is not inert: lua_ls infers the type of a `vim.opt` field from every
-- assignment it can reach, so `diffview-plus.nvim`, dropped for codediff in
-- `6f341e6` and still on disk, was assigning a list to `vim.opt.diffopt` and
-- turning `:append` into an undefined field in *this* repo's `options.lua`.
-- A stale directory checking a live one is the same class of failure as a
-- missing library: the gate reports on something that is not what runs.
--
-- The lockfile is also the same set CI installs, so the local gate and the CI
-- gate see one library rather than two.
local locked =
  vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(vim.fn.stdpath('config'), 'lazy-lock.json')), '\n'))
local names = vim.tbl_keys(locked)
table.sort(names)

local libs, missing = {}, {}
for _, name in ipairs(names) do
  local dir = vim.fs.joinpath(lazy_root, name)
  if vim.fn.isdirectory(dir) == 0 then
    table.insert(missing, name)
  elseif vim.fn.isdirectory(vim.fs.joinpath(dir, 'lua')) == 1 then
    -- A plugin with no `lua/` (vimscript, or data like friendly-snippets)
    -- contributes nothing to check against and is not an error.
    table.insert(libs, vim.fs.joinpath(dir, 'lua'))
  end
end
if #missing > 0 then
  die(('locked but not installed: %s - run `just plugins`'):format(table.concat(missing, ' ')))
end
if #libs == 0 then
  die(('no plugin `lua/` directories under %s - run `just plugins`'):format(lazy_root))
end

vim.list_extend(conf.workspace.library, libs)

vim.fn.writefile(vim.split(vim.json.encode(conf), '\n'), dst)
io.write(('%s: %d library entries (%d plugins)\n'):format(dst, #conf.workspace.library, #libs))
