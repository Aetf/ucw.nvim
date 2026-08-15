-- Dump every global mapping to a file, one line per (mode, lhs), sorted, for
-- diffing two boots against each other. This is Phase 8's core invariant
-- check ("no content changes", docs/design/phase8-keymap-registration.md §3):
-- run once on the pre-change tree, once after, and the diff must contain
-- nothing but the enumerated, intended deltas.
--
-- Callbacks cannot be compared across sessions (fresh closures every boot),
-- so they snapshot as '<callback>' and their `desc` carries the identity.
-- That is the same reasoning tests/test_keys.lua uses: a callback whose desc
-- is wrong or missing is invisible to which-key anyway.
--
-- Usage, from a *full-UI* instance (cond-gated specs must be loaded):
--   nvim --server <sock> --remote-expr or tui-drive:
--     :lua vim.g.ucw_snapshot_path = '/tmp/keymaps-before.txt'
--     :luafile scripts/keymap-snapshot.lua

local seen = {}
local out = {}
for _, query in ipairs { 'n', 'v', 's', 'o', 'i', 'c', 't' } do
  for _, m in ipairs(vim.api.nvim_get_keymap(query)) do
    -- A multi-mode mapping comes back once per queried mode with its own
    -- `mode` field (e.g. both 'v' and 's' report a ' ' or 'v' mapping);
    -- dedup on the mapping's own mode so it snapshots exactly once.
    local key = ('%s\t%s'):format(m.mode, m.lhs)
    -- `<Plug>` mappings are plugin-internal: unreachable by typing, created
    -- whenever the owning plugin happens to initialize that subsystem.
    -- Measured: blink.cmp's `<Plug>BlinkCmpDotRepeatHack` appears at a
    -- nondeterministic post-boot time (present in one boot's snapshot, absent
    -- 15s into an identical boot), so keeping them makes the diff flap on
    -- load-order noise that has nothing to do with key *registration*.
    if not seen[key] and not m.lhs:find('^<Plug>') then
      seen[key] = true
      local rhs = m.callback and '<callback>' or (m.rhs or '')
      table.insert(out, ('%s\t%s\t%s'):format(key, rhs, m.desc or ''))
    end
  end
end
table.sort(out)
vim.fn.writefile(out, vim.g.ucw_snapshot_path or '/tmp/keymap-snapshot.txt')
print(('snapshot: %d mappings -> %s'):format(#out, vim.g.ucw_snapshot_path or '/tmp/keymap-snapshot.txt'))
