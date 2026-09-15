# Keys

The key reference for `ucw.nvim`. `<leader>` is `<Space>`; press it and wait:
the which-key popup shows all of this in the editor, and `<leader>sk` searches
it. How a key is registered and tested: `extending.md` (recipes) and
`../AGENTS.md` (rules).

The grammar, before the tables:

- **Native vocabulary first.** LSP goes through Neovim's own `gr*` shapes
  (`grr` references, `gri` implementations, `grt` type definitions, `grn`
  rename, `gra` code actions, `gO` symbols), `K` hovers, and this config only
  swaps the list-producing ones for a picker.
- **`[`/`]` + a letter is previous/next in a sequence**, capital for first/last
  where native has it: `d` diagnostic, `q` quickfix, `c` git hunk, `h` python
  cell, `r` LSP reference. `g` is never a direction (`g[`/`g]` are mini.ai's
  left/right edge of a textobject).
- **`<leader>` + a letter is a namespace**, LazyVim's letters where LazyVim has
  one: `c` code, `f` find files, `s` search everything else, `g` git, `u`
  toggles, `b`/`w`/`t` buffer/window/tab, `q` quit and sessions, `r` REPL,
  `n` notifications, `l` the plugin manager. `d` (debugger) and `a` (AI) are
  reserved for features that do not exist yet.
- **`q` closes a window you only read**; `<Esc>` never does (it clears search
  highlight and notifications, and cancels input UIs). A terminal closes with
  the key that opened it.
- **`Tab`/`S-Tab` cycle buffers**; the jumplist keeps `<C-o>`/`<C-i>` (which
  needs a terminal that sends `<C-i>` distinctly from `Tab`, see
  `design/phase9-keybindings.md` §2.6), and `<C-S-o>`/`<C-S-i>` step it one
  *file* at a time. The mouse side buttons are the same pairs.

## Global keys

Generated from a real boot by `just keys-doc` (`scripts/keys-doc.lua`):
every key that exists after startup and is not identical to one in
`nvim --clean` (so a rebound default such as `grr` is listed, an untouched
one such as `gcc` is not), grouped by `<leader>` namespace, then by mode. `tests/test_keys_doc.lua` fails
when these tables and the config disagree, so edit the config, not the tables.
A `→` row is a plugin's own mapping shown by its right-hand side.

<!-- keys-doc:begin -->
### `<leader>?` — Buffer-local keymaps (which-key)

| key | mode | does |
|---|---|---|
| `<leader>?` | n | Buffer-local keymaps (which-key) |

### `` <leader>` `` — Go to alternate buffer

| key | mode | does |
|---|---|---|
| `` <leader>` `` | n | Go to alternate buffer |

### `<leader>b` — buffer

| key | mode | does |
|---|---|---|
| `<leader>bX` | n | Delete current buffer |
| `<leader>bb` | n | Go to buffer |
| `<leader>bd` | n | Pick Buffer To Close |
| `<leader>bx` | n | Delete current buffer |

### `<leader>c` — code

| key | mode | does |
|---|---|---|
| `<leader>ca` | n x | Code actions |
| `<leader>cf` | n x | Format the current buffer (or visual selection) |
| `<leader>cl` | n | Run codelens at current line |
| `<leader>cr` | n | Rename the symbol under cursor |

### `<leader>f` — find

| key | mode | does |
|---|---|---|
| `<leader>ff` | n | Find files |
| `<leader>fg` | n | Git files |
| `<leader>fr` | n | Recent files |

### `<leader>g` — git

| key | mode | does |
|---|---|---|
| `<leader>gR` | n | Reset buffer |
| `<leader>gS` | n | Stage buffer |
| `<leader>gb` | n | Blame line |
| `<leader>gd` | n | Diff with index |
| `<leader>gg` | n | Neogit |
| `<leader>gh` | n | History for current buffer |
| `<leader>gm` | n | Commit message for this diff |
| `<leader>goi` | n | Search issues |
| `<leader>goo` | n | Pick an action |
| `<leader>gop` | n | Search pull requests |
| `<leader>gp` | n | Preview hunk |
| `<leader>gr` | n | Reset hunk |
| `<leader>gr` | v | Reset hunk |
| `<leader>gs` | n | Stage hunk |
| `<leader>gs` | v | Stage hunk |
| `<leader>gu` | n | Undo stage hunk |

### `<leader>l` — Plugin manager (Lazy)

| key | mode | does |
|---|---|---|
| `<leader>l` | n | Plugin manager (Lazy) |

### `<leader>n` — Notification history

| key | mode | does |
|---|---|---|
| `<leader>n` | n | Notification history |

### `<leader>q` — quit/session

| key | mode | does |
|---|---|---|
| `<leader>ql` | n | List and open sessions |
| `<leader>qq` | n | Quit all |
| `<leader>qr` | n | Manually restore session |
| `<leader>qs` | n | Manually save session |

### `<leader>r` — repl

| key | mode | does |
|---|---|---|
| `<leader>r<CR>` | n | Send a return to the REPL |
| `<leader>rc` | n | Interrupt the REPL |
| `<leader>rf` | n | Send the whole file to the REPL |
| `<leader>rl` | n | Send the current line to the REPL |
| `<leader>rq` | n | Exit the REPL |
| `<leader>rr` | n | Toggle the REPL window |
| `<leader>rs` | n | Send a motion to the REPL |
| `<leader>rs` | v | Send the selection to the REPL |
| `<leader>rx` | n | Clear the REPL screen |

### `<leader>s` — search

| key | mode | does |
|---|---|---|
| `<leader>s<Space>` | n | All pickers |
| `<leader>sD` | n | Diagnostics for the whole workspace |
| `<leader>sS` | n | Symbols in the current workspace |
| `<leader>sb` | n | Search lines in file |
| `<leader>sc` | n | Command history |
| `<leader>sd` | n | Diagnostics for current buffer |
| `<leader>sg` | n | Grep in CWD |
| `<leader>sh` | n | Search help |
| `<leader>sk` | n | Search keymaps |
| `<leader>sm` | n | Search all messages |
| `<leader>ss` | n | Symbols in the current buffer |
| `<leader>sw` | n x | Grep word under cursor (or selection) |

### `<leader>t` — tab

| key | mode | does |
|---|---|---|
| `<leader>tc` | n | Open new tab page |
| `<leader>tn` | n | Go to next tab |
| `<leader>to` | n | Close other tabs |
| `<leader>tp` | n | Go to previous tab |
| `<leader>tx` | n | Close current tab |

### `<leader>u` — toggle/ui

| key | mode | does |
|---|---|---|
| `<leader>uD` | n | Toggle Diagnostics |
| `<leader>ub` | n | Toggle Current line blame |
| `<leader>ud` | n | Toggle Show deleted |
| `<leader>uh` | n | Toggle Inlay Hints |
| `<leader>un` | n | Dismiss notifications |
| `<leader>us` | n | Toggle Spelling |
| `<leader>uv` | n v | Toggle Diagnostic virtual lines |
| `<leader>uw` | n | Toggle Wrap |

### `<leader>w` — window

| key | mode | does |
|---|---|---|
| `<leader>ws` | n | Split window horizontally |
| `<leader>wv` | n | Split window vertically |
| `<leader>wx` | n | Close current window |

### Normal mode (and the visual/operator twins of these keys)

| key | mode | does |
|---|---|---|
| `,` | n x o | → `<Plug>Lightspeed_,_ft` |
| `0` | n | Go to first non-blank character |
| `;` | n x o | → `<Plug>Lightspeed_;_ft` |
| `<BS>` | n | → `<Plug>(fold-cycle-close)` |
| `<C-B>` | n x s | Scroll a page up (smooth) |
| `<C-CR>` | n v i | Send block to REPL |
| `<C-D>` | n x s | Scroll half a page down (smooth) |
| `<C-E>` | n x s | Scroll the view down a little (smooth) |
| `<C-F>` | n x s | Scroll a page down (smooth) |
| `<C-P>` | n | Find file (frecency) |
| `<C-PageDown>` | n | Go To Next Buffer |
| `<C-PageUp>` | n | Go To Previous Buffer |
| `<C-S-I>` | n | Jump forward to the next file (jumplist) |
| `<C-S-O>` | n | Jump back to the previous file (jumplist) |
| `<C-S>` | n | Write file |
| `<C-S>` | v i | Write file |
| `<C-U>` | n x s | Scroll half a page up (smooth) |
| `<C-Y>` | n x s | Scroll the view up a little (smooth) |
| `<C-_>` | n | Toggle comment on this line |
| `` <C-`> `` | n | Toggle Terminal |
| `<CR>` | n | → `Fold_cycle_is_quick_fix_or_commandline() ? "\<CR>" : "<Plug>(fold-cycle-open)"` |
| `<Esc>` | n | Clear search highlight and notifications |
| `<M-Bar>` | n | Go to last tab |
| `<M-Bslash>` | n t | Go to last window |
| `<M-F>` | n | Find in CWD |
| `<M-H>` | n | Move line left |
| `<M-J>` | n | Move line down |
| `<M-K>` | n | Move line up |
| `<M-L>` | n | Move line right |
| `<M-f>` | n | Find in File |
| `<M-h>` | n t | Go to left window |
| `<M-j>` | n t | Go to down window |
| `<M-k>` | n t | Go to up window |
| `<M-l>` | n t | Go to right window |
| `<M-n>` | n | Go to next tab |
| `<M-p>` | n | Go to previous tab |
| `<S-CR>` | n v i | Send block to REPL and move to next |
| `<S-Tab>` | n | Go to previous buffer |
| `<S-X1Mouse>` | n | Jump back to the previous file (jumplist) |
| `<S-X2Mouse>` | n | Jump forward to the next file (jumplist) |
| `<Tab>` | n | Go to next buffer |
| `<X1Mouse>` | n v | Jump back (jumplist) |
| `<X2Mouse>` | n v | Jump forward (jumplist) |
| `F` | n x o | → `<Plug>Lightspeed_F` |
| `K` | n | Peek the fold under the cursor, else hover |
| `S` | n x | → `<Plug>Lightspeed_S` |
| `T` | n x o | → `<Plug>Lightspeed_T` |
| `[c` | n | Prev hunk |
| `\` | n | Toggle file tree |
| `]c` | n | Next hunk |
| `^` | n | Go to start of line |
| `cs` | n | Replace surrounding |
| `csl` | n | Replace previous surrounding |
| `csn` | n | Replace next surrounding |
| `ds` | n | Delete surrounding |
| `dsl` | n | Delete previous surrounding |
| `dsn` | n | Delete next surrounding |
| `f` | n x o | → `<Plug>Lightspeed_f` |
| `gO` | n | Symbols in the current buffer |
| `gS` | n | → `<Plug>Lightspeed_gS` |
| `g[` | n x o | Move to left "around" |
| `g]` | n x o | Move to right "around" |
| `gri` | n | Go to implementation |
| `grr` | n | Find references |
| `grt` | n | Go to type definition |
| `gs` | n | → `<Plug>Lightspeed_omni_gs` |
| `j` | n | Down (visual line, or physical with a count) |
| `k` | n | Up (visual line, or physical with a count) |
| `p` | n | Paste after cursor, keep cursor put |
| `s` | n | → `<Plug>Lightspeed_omni_s` |
| `t` | n x o | → `<Plug>Lightspeed_t` |
| `ys` | n | Add surrounding |
| `zM` | n | Close all folds |
| `zR` | n | Open all folds |
| `zb` | n x s | Cursor line to the bottom (smooth) |
| `zt` | n x s | Cursor line to the top (smooth) |
| `zz` | n x s | Cursor line to the middle (smooth) |
| `\|` | n | Toggle file tree (focus) |

### Visual mode only

| key | mode | does |
|---|---|---|
| `<M-H>` | x | Move left |
| `<M-J>` | x | Move down |
| `<M-K>` | x | Move up |
| `<M-L>` | x | Move right |
| `a` | x o | Around textobject |
| `al` | x o | Around last textobject |
| `an` | x o | Around next textobject |
| `i` | x o | Inside textobject |
| `ic` | x o | Select hunk (change)  |
| `il` | x o | Inside last textobject |
| `in` | x o | Inside next textobject |
| `s` | x | → `<Plug>Lightspeed_s` |
| `ys` | x | Add surrounding to selection |

### Operator-pending mode only

| key | mode | does |
|---|---|---|
| `X` | o | → `<Plug>Lightspeed_X` |
| `Z` | o | → `<Plug>Lightspeed_S` |
| `x` | o | → `<Plug>Lightspeed_x` |
| `z` | o | → `<Plug>Lightspeed_s` |

### Insert mode

| key | mode | does |
|---|---|---|
| `<C-R>` | i | Paste a register literally (no autoindent) |
| `<C-R><C-O>` | i | Paste a register as typed |
| `` <C-`> `` | i | Toggle Terminal |
| `<X1Mouse>` | i | Jump back (jumplist) |
| `<X2Mouse>` | i | Jump forward (jumplist) |

### Command-line mode

| key | mode | does |
|---|---|---|
| `<C-E>` | c | blink.cmp: Cancel |
| `<C-N>` | c | blink.cmp: Select Next |
| `<C-P>` | c | blink.cmp: Select Prev |
| `<C-Space>` | c | blink.cmp: Show |
| `<C-Y>` | c | blink.cmp: Select And Accept |
| `<End>` | c | blink.cmp: Hide |
| `<Left>` | c | blink.cmp: Select Prev |
| `<Right>` | c | blink.cmp: Select Next |
| `<S-Tab>` | c | blink.cmp: <Custom Fn>, Select Prev |
| `<Tab>` | c | blink.cmp: Show And Insert Or Accept Single, Select Next |

### Terminal mode

| key | mode | does |
|---|---|---|
| `<Esc><Esc>` | t | Leave terminal mode |

<!-- keys-doc:end -->

## Buffer-local keys

These exist only in the buffers that need them, so `nvim_get_keymap` and the
tables above never see them. Each set has a test that asserts both halves:
present where it should be, absent elsewhere.

### With an LSP client attached (`lua/ucw/lsp/attach.lua`)

| key | mode | does |
|---|---|---|
| `gd` | n | Go to definition (picker) |
| `gD` | n | Go to declaration |
| `<M-CR>` | n x | Code actions |
| `<C-k>` | n | Show diagnostics on the current line |
| `[r` / `]r` | n | Previous / next reference of the symbol under the cursor (snacks.words; the same references are highlighted automatically) |

Rust buffers (rustaceanvim) override `<leader>ca` buffer-locally with
rust-analyzer's grouped code actions.

Inlay hints and codelens are enabled per buffer on attach; `<leader>uh`
toggles inlay hints globally (the toggle is the user preference, each new
buffer follows it).

### Python (`ftplugin/python.lua`, `lua/ucw/textobjects/ipython.lua`)

| key | mode | does |
|---|---|---|
| `[h` / `]h` | n x | Previous / next `# %%` cell |
| `ih` / `ah` | textobject | The current cell's code / the cell with its `# %%` marker |
| `iH` / `aH` | textobject | Same, keeping the blank edge lines |
| `<C-CR>` / `<S-CR>` | n v i | Send the current cell to the REPL (global keys, `<leader>r` namespace); `<S-CR>` then moves to the next cell |

### Git buffers

| where | key | does |
|---|---|---|
| neogit status and log view | `<CR>` on a commit | Open the commit in codediff (on a file row it still opens the file) |
| neogit status | `<Esc>` | Close (neogit's own convention in its other buffers) |
| neogit or a codediff tab | `<leader>gm` | Float with the full commit message (global key; resolves the commit from whichever side it is pressed on) |
| any buffer | `[c` / `]c` | Previous / next hunk (inside `:diffthis` the native change motion) |
| any buffer | `ic` | Textobject: the hunk under the cursor |

### Windows that close on `q`

`help` and quickfix/location-list windows map `q` to `<C-w>q` (Neovim's own
`man` convention). Every other read-only window this config opens (lazy,
mason, checkhealth, neo-tree, pickers, notification history, noice views,
codediff tabs, neogit, hover floats, gitsigns previews) already closes on
`q` by its plugin's default.

### File tree (neo-tree window)

Beyond neo-tree's defaults:

| key | does |
|---|---|
| `h` / `l` | Move out of / into a directory (close / open it) |
| `J` / `K` | First / last sibling |
| `oh` / `ov` | Open in a vertical (side-by-side) / horizontal (stacked) split |
| `O` | Open with the system handler |
| `s` / `S` | lightspeed jump inside the tree |
| `zo zO zc zC za zA zx zX zm zM zr zR` | Vim fold keys, emulated over the tree (`zR` expands everything, `zm` steps back) |

`\` toggles the tree and `|` toggles it with focus (global keys).

### Terminal

`` <C-`> `` toggles the floating terminal from any mode (toggleterm); inside it
`<Esc><Esc>` leaves terminal mode and `` <C-`> `` closes it again. The REPL
window is `<leader>rr`.

### Completion (blink.cmp, `enter` preset)

`<CR>` accepts, `<C-Space>` opens or toggles documentation, `<C-e>` hides,
`<C-n>`/`<C-p>` and `<Up>`/`<Down>` move, `<C-b>`/`<C-f>` scroll the
documentation, `<Tab>`/`<S-Tab>` jump through snippet placeholders (when a
snippet is active; otherwise the key is itself), `<C-k>` toggles signature
help.

### Textobjects and surround (mini.nvim)

`aF`/`iF` function, `aB`/`iB` block, `aC`/`iC` class (treesitter), `ah`/`ih`
python cell, plus mini.ai's defaults (`aq`/`iq` any quote, `ab`/`ib` any
bracket, `a?` prompted, …); `g[`/`g]` go to the left/right edge of the
textobject. Surround: `ys` add, `ds` delete, `cs` replace. `<M-S-h/j/k/l>`
moves the selection or line (mini.move; the unshifted `<M-h/j/k/l>` are
window navigation).
