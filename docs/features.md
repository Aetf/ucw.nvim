# Features

What `ucw.nvim` does for you once it is installed, by area. Keys are in
`keys.md`; the code map is in `architecture.md`; how to change any of this is
in `extending.md`.

## Editing defaults

- 4-space indent with `expandtab`, `smartindent`; `textwidth` 80 with no
  hard wrap (`wrap` off, `linebreak` on for the files that wrap themselves);
  tabs, trailing and non-breaking spaces drawn (`list`).
- Relative line numbers, cursor line, a sign column that is always there, a
  one-column fold gutter; 24-bit colour, `base16-eighties`.
- Search ignores case unless the pattern has capitals; `:s` previews in a
  split (`inccommand`); matching brackets flash.
- New splits open below / to the right; the mouse works in normal, visual
  and insert mode with a popup right-click menu; `h`/`l` and the arrows
  wrap across lines.
- Persistent undo (`undodir` under the data directory), a large `shada`,
  file encodings that also try the common Chinese and Japanese ones.
- `<leader>` timeout 500 ms; `updatetime` 300 ms (drives `CursorHold`).

## What happens by itself

- **Reading a file** restores the last cursor position; yanking flashes the
  yanked text.
- **Files changed on disk** are reloaded: `autoread` is on and `:checktime`
  runs on focus, buffer enter, idle and leaving a terminal, so a formatter or
  a `git checkout` shows up within `updatetime` without a keypress. A
  modified buffer is never overwritten (Neovim's W12 prompt instead), and
  every reload says so in a notification; a file deleted underneath you is
  left alone.
- **Closing a window** returns to the window you came from, not to
  whichever Neovim would pick.
- **`:W`** writes the file as root through `pkexec`.
- **Sessions** are saved per directory on exit (auto-session; not under
  `~`, `/tmp`, `/dev/shm`). Restore is manual: `<leader>qr` for this
  directory, `<leader>ql` to pick one. Before a save, auxiliary windows
  (file tree, help, codediff tabs, pickers) are closed so a restore brings
  back your files and nothing else.
- **Notifications** render through noice into the snacks notifier;
  `<leader>n` is the history, `<leader>sm` searches every message ever
  shown, `<Esc>` in normal mode dismisses them along with search highlight.
  LSP progress shows only in the statusline.
- **Format on save** runs conform with a 500 ms budget, in the full editor
  UI only (never under firenvim or vscode-neovim). Which formatter: see
  *Languages* below.

## Languages

Language servers start on their own when you open a supported file; there
is nothing to enable. Mason installs the binaries on first use
(`:Mason` shows them); a binary the project itself provides (a virtualenv,
`mise`, `nix develop`) wins over Mason's, because Mason's `bin/` is appended
to `PATH`, never prepended. `:checkhealth ucw` prints which copy of each
declared binary is actually running and flags anything installed that
nothing declares, or declared and not installed.

| filetype | server(s) | formatter | notes |
|---|---|---|---|
| lua | lua_ls | stylua | lua_ls's own formatter is blocked; lazydev types the Neovim API |
| python | basedpyright, ruff | ruff | ruff's hover is declined (it answers nothing); `# %%` cells, see *REPL* |
| c, cpp, cuda, objc | clangd | (clangd) | clangd_extensions |
| rust | rust-analyzer (rustaceanvim) | rustfmt via the server | rustaceanvim owns the client; grouped code actions on `<leader>ca` |
| tex, plaintex, bib | texlab, ltex_plus | none | texlab's formatter is blocked; `formatexpr` reflows one sentence per line; SyncTeX forward search and zathura backward search |
| markdown | marksman, ltex_plus | prettier (if installed) | |
| toml | taplo | taplo | |
| json, jsonc | jsonls | | |

Once a client is attached (`keys.md` § buffer-local): `gd`/`gD`, code
actions on `<M-CR>`, the diagnostic float on `<C-k>`, references highlighted
automatically with `[r`/`]r` to walk them; inlay hints and codelens on;
`K` hovers; `grr`/`gri`/`grt`/`gO` open pickers; `<leader>c*` is rename,
format, code action, codelens; `<leader>s*` has document and workspace
symbols and diagnostics.

**Diagnostics** show as signs and in the float; virtual lines are off by
default and `<leader>uv` turns them on for the current line. `[d`/`]d`
walk them, `<leader>sd`/`sD` list them.

**Workspace settings** come from the project's `.vscode/settings.json`
(and the user-scope directory): whatever a server reads under its
`settings` key is loaded on attach and pushed again on every change to that
file. Text-file sidecars sit next to it for list-valued keys — the ltex
dictionaries, disabled rules and hidden false positives are
`.vscode/ltex.dictionary.<lang>.txt` and friends — and ltex's *add to
dictionary* / *hide false positive* / *disable rule* code actions write to
them, so the project keeps its own word list.

**Completion** is blink.cmp: LSP, path, snippets (`friendly-snippets` over
native `vim.snippet`), buffer words after six characters; signature help on
`<C-k>`; the command line completes too.

**Treesitter** highlights, folds (through ufo, with a line count in the
fold text and `K` to peek), indents, and provides the `F`/`B`/`C`
textobjects. Parsers for the languages in `treesitter.lua` are installed
and updated at startup when the `tree-sitter` CLI is on `PATH` (a warning
once per session when it is not). `gc` comments through Neovim's own
commenting, with the injected language's comment string inside a fence.

## Git

- **gitsigns** for the gutter, hunk motions `[c`/`]c`, stage / reset /
  preview / blame under `<leader>g`, current-line blame and show-deleted
  toggles under `<leader>u`.
- **neogit** (`<leader>gg`) for status, log, commit, push; `<CR>` on any
  commit opens it in **codediff**, `<leader>gm` shows its message.
- **codediff** for every diff view: `<leader>gh` is the current file's
  history; neogit's `dd`/diff popup opens the same views. The diff panes are
  the real file buffers, so LSP and treesitter work inside them.
- **octo** for GitHub issues and pull requests (`<leader>go*`).

## Finding things

snacks.picker for everything: `<C-p>` opens files by frecency (recent first,
current directory boosted), `<leader>f*` files / recent / git files,
`<leader>s*` grep, buffer lines, word under cursor (or the selection),
command history, keymaps, help, messages, and `<leader>s<Space>` lists every
picker. `<leader>bb` is the buffer list (closing a buffer from inside it
goes through the same jumplist-aware close as `<leader>bd`); `\`/`|` the
file tree.

## REPL

iron.nvim under `<leader>r`: `rr` opens the REPL for the current filetype
(ipython for python), `rs` sends a motion or the visual selection, `rl` a
line, `rf` the file, `<C-CR>` the current `# %%` cell (`<S-CR>` then moves
to the next one). When the REPL binary is missing the keys warn once and do
nothing.

## Windows, tabs, terminal

`<M-h/j/k/l>` move between windows (and tmux panes, through Navigator);
`<leader>w*` splits with the `<C-w>` letters; `<leader>t*` tabs, `<M-n>`/
`<M-p>` next/previous tab; `Tab`/`S-Tab` cycle buffers (bufferline), the
jumplist stays on `<C-o>`/`<C-i>` and steps a whole file at a time with
Shift. `` <C-` > `` is a floating terminal.

## Embedded contexts

- **firenvim** (browser text areas): light theme, no statusline, no
  hard-wrap; GitHub text areas are markdown; `<Esc><Esc>` focuses the page
  and `<C-z>` hides the frame. Format-on-save and file reloads are off
  (a write is the push back to the page).
- **vscode-neovim**: the tabline, gutter, sessions, folding, indent guides,
  the LSP stack and which-key do not load (VSCode owns all of that);
  motions, textobjects, surround, comments, the pickers and the core keys
  still work.

## Health

`:checkhealth ucw` reports, per declared binary, where on `PATH` it
resolved (project copy or Mason's floor), what is declared versus installed
versus the registry's version, whether the `tree-sitter` CLI is reachable,
and that Mason is last on `PATH`.
