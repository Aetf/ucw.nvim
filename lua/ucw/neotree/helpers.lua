local M = {}

local renderer = require('neo-tree.ui.renderer')

-- Set width to be the same as content
function M.width_fit_content(state)
  local root_name = vim.fn.fnamemodify(state.path, ':~')
  local root_len = string.len(root_name) + 4
  return math.max(root_len, 30)
end

-- Expand a node and load filesystem info if needed.
--
-- `path_to_reveal` is nil on purpose - "reveal nothing" - and neo-tree v3
-- annotates that third parameter `string` rather than `string?`, which its own
-- code contradicts twice over: `toggle_directory` forwards the value to
-- `fs_scan.get_items`, whose wrappers annotate it `string?` and whose reveal
-- step is `if path_to_reveal then` (`lib/fs_scan.lua:533/541/618`), and
-- upstream's own caller passes nothing after the node
-- (`common/commands.lua:797`). Same annotation, same evidence, at both
-- `toggle_directory` calls in `move_out`/`move_in` below.
local function open_dir(state, dir_node)
  local fs = require('neo-tree.sources.filesystem')
  ---@diagnostic disable-next-line: param-type-mismatch
  fs.toggle_directory(state, dir_node, nil, true, false)
end

-- Expand a node and all its children, optionally stopping at max_depth.
local function recursive_open(state, node, max_depth)
  local max_depth_reached = 1
  local stack = { node }
  while next(stack) ~= nil do
    node = table.remove(stack)
    if node.type == 'directory' and not node:is_expanded() then
      open_dir(state, node)
    end

    local depth = node:get_depth()
    max_depth_reached = math.max(depth, max_depth_reached)

    if not max_depth or depth < max_depth - 1 then
      local children = state.tree:get_nodes(node:get_id())
      for _, v in ipairs(children) do
        table.insert(stack, v)
      end
    end
  end

  return max_depth_reached
end

-- The nodes inside the root folder are depth 2.
local MIN_DEPTH = 2

-- Expand whole subtrees the way neo-tree does it, rather than by walking them
-- here. Loading a directory is asynchronous: `toggle_directory` returns with
-- the node still `loaded == false` and no children in the tree, so
-- `recursive_open`, which opens a node and immediately asks for its children,
-- sees none and stops one level short. Measured on a cold tree, `zR` used to
-- descend exactly one more level per press - 16, 55, 98, 152 lines - instead
-- of expanding everything once.
--
-- `node_expander` is upstream's answer to the same problem: it collects the
-- nodes that were not loaded, runs the source's `prefetcher` over them and
-- expands again. It has to run inside a coroutine, which is why `done` exists
-- - the completion callback is the point at which the tree is really expanded,
-- and it is a callback rather than a wait, so nothing here guesses at timing.
--
-- `recursive_open` still serves the depth-limited keys (`zo` with a count,
-- `zr`, `zx`), which ask for one more level at a time and so are asking about
-- nodes that are already loaded.
local function expand_all(state, roots, done)
  local async = require('plenary.async')
  local node_expander = require('neo-tree.sources.common.node_expander')
  local prefetcher = require('neo-tree.sources.filesystem').prefetcher

  renderer.position.set(state, nil)
  async.run(function()
    for _, root in ipairs(roots) do
      node_expander.expand_directory_recursively(state, root, prefetcher)
    end
  end, function()
    if done then
      done()
    end
    renderer.redraw(state)
  end)
end

-- The depthlevel a fully expanded tree corresponds to, so that `zm` after `zR`
-- collapses one level from the bottom rather than from a number `zR` guessed
-- before the expansion had happened. `set_depthlevel` opens a directory when
-- its depth is *below* the level, hence the +1.
local function deepest_expanded(state)
  local deepest = MIN_DEPTH
  for _, node in pairs(state.tree.nodes.by_id) do
    if node.type == 'directory' and node:is_expanded() then
      deepest = math.max(deepest, node:get_depth() + 1)
    end
  end
  return deepest
end

--- Close the node and its parents, optionally stopping at max_depth.
local function recursive_close(state, node, max_depth)
  if max_depth == nil or max_depth <= MIN_DEPTH then
    max_depth = MIN_DEPTH
  end

  local last = node
  while node and node:get_depth() >= max_depth do
    if node:has_children() and node:is_expanded() then
      node:collapse()
    end
    last = node
    node = state.tree:get_node(node:get_parent_id())
  end

  return last
end

--- Set depthlevel, analagous to foldlevel, for the neo-tree file tree.
local function set_depthlevel(state, depthlevel)
  if depthlevel < MIN_DEPTH then
    depthlevel = MIN_DEPTH
  end

  local stack = state.tree:get_nodes()
  while next(stack) ~= nil do
    local node = table.remove(stack)

    if node.type == 'directory' then
      local should_be_open = depthlevel == nil or node:get_depth() < depthlevel
      if should_be_open and not node:is_expanded() then
        open_dir(state, node)
      elseif not should_be_open and node:is_expanded() then
        node:collapse()
      end
    end

    local children = state.tree:get_nodes(node:get_id())
    for _, v in ipairs(children) do
      table.insert(stack, v)
    end
  end

  vim.b.neotree_depthlevel = depthlevel
end

--- Refresh the tree UI after a change of depthlevel.
-- @bool stay Keep the current node revealed and selected
local function redraw_after_depthlevel_change(state, stay)
  -- `get_node()` resolves the *cursor's line* against the tree, and by this
  -- point `set_depthlevel` has already collapsed nodes while the buffer still
  -- shows the longer rendering - so a cursor below the new end of the tree
  -- resolves to nothing. Reachable in three keystrokes: `zR`, `G`, `zm`. It
  -- raised "attempt to index local 'node'" and, because that aborted before
  -- the redraw, the visible symptom was `zm` silently doing nothing.
  -- Same for a parent lookup that walks off the root.
  local node = state.tree:get_node()
  if not node then
    return renderer.redraw(state)
  end

  if stay then
    require('neo-tree.ui.renderer').expand_to_node(state.tree, node)
  else
    -- Find the closest parent that is still visible.
    local parent = state.tree:get_node(node:get_parent_id())
    while parent and not parent:is_expanded() and parent:get_depth() > 1 do
      node = parent
      parent = state.tree:get_node(node:get_parent_id())
    end
  end

  renderer.redraw(state)
  renderer.focus_node(state, node:get_id())
end

-----------------------------------------------------------------------------------------
-- Commands
-----------------------------------------------------------------------------------------

M.commands = {}

-- Open file with system default application
function M.commands.system_open(state)
  local node = state.tree:get_node()
  local path = node:get_id()
  -- open file in default application in the background
  vim.api.nvim_command(string.format("silent !open -g '%s'", path)) -- for mac
  vim.api.nvim_command(string.format("silent !xdg-open '%s'", path)) -- for linux
end

-- Move to first sibling
function M.commands.first_sibling(state)
  local tree = state.tree
  local node = tree:get_node()
  local siblings = tree:get_nodes(node:get_parent_id())
  local renderer = require('neo-tree.ui.renderer')
  renderer.focus_node(state, siblings[#siblings]:get_id())
end

-- Move to last sibling
function M.commands.last_sibling(state)
  local tree = state.tree
  local node = tree:get_node()
  local siblings = tree:get_nodes(node:get_parent_id())
  local renderer = require('neo-tree.ui.renderer')
  renderer.focus_node(state, siblings[1]:get_id())
end

--- Open the fold under the cursor, recursing if count is given.
function M.commands.neotree_zo(state, open_all)
  local node = state.tree:get_node()
  if not node then
    return
  end

  if open_all then
    return expand_all(state, { node })
  end

  recursive_open(state, node, node:get_depth() + vim.v.count1)
  renderer.redraw(state)
end

--- Recursively open the current folder and all folders it contains.
function M.commands.neotree_zO(state)
  M.commands.neotree_zo(state, true)
end

--- Close a folder, or a number of folders equal to count.
function M.commands.neotree_zc(state, close_all)
  local node = state.tree:get_node()
  if not node then
    return
  end

  local max_depth
  if not close_all then
    max_depth = node:get_depth() - vim.v.count1
    if node:has_children() and node:is_expanded() then
      max_depth = max_depth + 1
    end
  end

  local last = recursive_close(state, node, max_depth)
  renderer.redraw(state)
  renderer.focus_node(state, last:get_id())
end

-- Close all containing folders back to the top level.
function M.commands.neotree_zC(state)
  M.commands.neotree_zc(state, true)
end

--- Open a closed folder or close an open one, with an optional count.
function M.commands.neotree_za(state, toggle_all)
  local node = state.tree:get_node()
  if not node then
    return
  end

  if node.type == 'directory' and not node:is_expanded() then
    M.commands.neotree_zo(state, toggle_all)
  else
    M.commands.neotree_zc(state, toggle_all)
  end
end

--- Recursively close an open folder or recursively open a closed folder.
function M.commands.neotree_zA(state)
  M.commands.neotree_za(state, true)
end

--- Update all open/closed folders by depthlevel, then reveal current node.
function M.commands.neotree_zx(state)
  set_depthlevel(state, vim.b.neotree_depthlevel or MIN_DEPTH)
  redraw_after_depthlevel_change(state, true)
end

--- Update all open/closed folders by depthlevel.
function M.commands.neotree_zX(state)
  set_depthlevel(state, vim.b.neotree_depthlevel or MIN_DEPTH)
  redraw_after_depthlevel_change(state, false)
end

-- Collapse more folders: decrease depthlevel by 1 or count.
function M.commands.neotree_zm(state)
  local depthlevel = vim.b.neotree_depthlevel or MIN_DEPTH
  set_depthlevel(state, depthlevel - vim.v.count1)
  redraw_after_depthlevel_change(state, false)
end

-- Collapse all folders. Set depthlevel to MIN_DEPTH.
function M.commands.neotree_zM(state)
  set_depthlevel(state, MIN_DEPTH)
  redraw_after_depthlevel_change(state, false)
end

-- Expand more folders: increase depthlevel by 1 or count.
function M.commands.neotree_zr(state)
  local depthlevel = vim.b.neotree_depthlevel or MIN_DEPTH
  set_depthlevel(state, depthlevel + vim.v.count1)
  redraw_after_depthlevel_change(state, false)
end

-- Expand all folders. Set depthlevel to the deepest node level.
function M.commands.neotree_zR(state)
  expand_all(state, state.tree:get_nodes(), function()
    -- `state.bufnr`, not `vim.b`: by the time this runs the current buffer is
    -- whatever it happens to be, and the depthlevel belongs to the tree.
    vim.b[state.bufnr].neotree_depthlevel = deepest_expanded(state)
  end)
end

-- up to parent dir when on a file, close dir when on a dir
function M.commands.move_out(state)
  local node = state.tree:get_node()
  if node.type == 'directory' and node:is_expanded() then
    ---@diagnostic disable-next-line: missing-parameter
    require('neo-tree.sources.filesystem').toggle_directory(state, node)
  else
    require('neo-tree.ui.renderer').focus_node(state, node:get_parent_id())
  end
end

-- open dir when on a dir, noop when on a file
function M.commands.move_in(state)
  local node = state.tree:get_node()
  if node.type == 'directory' then
    if not node:is_expanded() then
      ---@diagnostic disable-next-line: missing-parameter
      require('neo-tree.sources.filesystem').toggle_directory(state, node)
    elseif node:has_children() then
      require('neo-tree.ui.renderer').focus_node(state, node:get_child_ids()[1])
    end
  end
end

-- Toggle hidden files. Overrides the builtin only to drop its `log.info`
-- notification: the redrawn tree already shows whether dotfiles are in it.
function M.commands.toggle_hidden(state)
  state.filtered_items.visible = not state.filtered_items.visible
  require('neo-tree.sources.filesystem')._navigate_internal(state, nil, nil, nil, false)
end

return M
