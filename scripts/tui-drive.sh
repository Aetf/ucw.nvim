#!/usr/bin/env bash
# tui-drive.sh — drive a real Neovim TUI in a detached tmux session and observe
# what it actually renders (screen text, colors, cursor), for interactive/agent
# debugging of this config.
#
# It combines two channels:
#   * a tmux session         -> real terminal rendering, read back with capture-pane
#   * an nvim --listen socket -> reliable scripted control + :messages + screenshots
#
# Quick start:
#   scripts/tui-drive.sh start            # boot the real config
#   scripts/tui-drive.sh capture          # dump the current screen (plain text)
#   scripts/tui-drive.sh send ':lua Snacks.picker.files()<CR>'
#   scripts/tui-drive.sh capture
#   scripts/tui-drive.sh messages         # :messages content
#   scripts/tui-drive.sh stop
#
# Notes:
#   * `start` with no args loads the *real* ~/.config/nvim config. Pass extra nvim
#     args after `start` to change that, e.g.
#       scripts/tui-drive.sh start --clean -u tests/aux/driver_init.lua
#       scripts/tui-drive.sh start README.md
#   * `send` uses Neovim key notation (<CR>, <Esc>, <C-w>, <leader> is a literal
#     space by default here). Use `keys` for raw tmux key events (e.g. C-c).
set -euo pipefail

SESSION="${UCW_TUI_SESSION:-ucw-tui}"
SOCK="${UCW_TUI_SOCK:-${XDG_RUNTIME_DIR:-/tmp}/ucw-tui.sock}"
COLS="${UCW_TUI_COLS:-200}"
ROWS="${UCW_TUI_ROWS:-50}"
NVIM="${UCW_TUI_NVIM:-nvim}"

die() { echo "tui-drive: $*" >&2; exit 1; }

require_running() {
  tmux has-session -t "$SESSION" 2>/dev/null || die "no session '$SESSION' (run: $0 start)"
  [[ -S "$SOCK" ]] || die "control socket '$SOCK' missing"
}

cmd_start() {
  command -v tmux >/dev/null || die "tmux not found"
  command -v "$NVIM" >/dev/null || die "nvim not found"
  cmd_stop >/dev/null 2>&1 || true
  rm -f "$SOCK"
  # Detached session at a fixed, generous size so wrapping is predictable.
  tmux new-session -d -s "$SESSION" -x "$COLS" -y "$ROWS" \
    "$NVIM --listen '$SOCK' $*"
  # Wait for the control socket + a live API channel.
  for _ in $(seq 1 100); do
    if [[ -S "$SOCK" ]] && "$NVIM" --server "$SOCK" --remote-expr '1' >/dev/null 2>&1; then
      echo "started session=$SESSION sock=$SOCK size=${COLS}x${ROWS}"
      return 0
    fi
    sleep 0.1
  done
  die "nvim did not come up (see: tmux attach -t $SESSION)"
}

cmd_stop() {
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  rm -f "$SOCK"
  echo "stopped $SESSION"
}

# Scripted input via the control socket (Neovim key notation).
cmd_send() {
  require_running
  [[ $# -ge 1 ]] || die "send needs keys, e.g. send ':messages<CR>'"
  "$NVIM" --server "$SOCK" --remote-send "$*"
}

# Raw terminal key events via tmux (for things the RPC channel can't inject,
# e.g. C-c to interrupt). Uses tmux send-keys syntax.
cmd_keys() {
  require_running
  # shellcheck disable=SC2086
  tmux send-keys -t "$SESSION" "$@"
}

# Evaluate a Vimscript expression and print the result.
cmd_expr() {
  require_running
  [[ $# -ge 1 ]] || die "expr needs an expression"
  "$NVIM" --server "$SOCK" --remote-expr "$*"
  echo
}

# Run an ex command (normal-mode first, so it works from any mode).
cmd_cmd() {
  require_running
  [[ $# -ge 1 ]] || die "cmd needs an ex command"
  "$NVIM" --server "$SOCK" --remote-send "<C-\\><C-N>:$*<CR>"
}

# Evaluate Lua and print the result (via luaeval).
cmd_lua() {
  require_running
  [[ $# -ge 1 ]] || die "lua needs a chunk, e.g. lua 'return vim.version().minor'"
  "$NVIM" --server "$SOCK" --remote-expr "luaeval('(function() $* end)()')"
  echo
}

# Dump the current screen as plain text (trailing whitespace trimmed).
cmd_capture() {
  require_running
  tmux capture-pane -t "$SESSION" -p | sed -e 's/[[:space:]]*$//'
}

# Dump the current screen with SGR color/attribute escapes preserved.
cmd_capture_color() {
  require_running
  tmux capture-pane -t "$SESSION" -e -p
}

# Print :messages (the message history), routed through the control socket so it
# never blocks on a hit-enter prompt.
cmd_messages() {
  require_running
  "$NVIM" --server "$SOCK" --remote-expr "execute('silent messages')"
  echo
}

# Write an nvim__screenshot (internal grid dump) to a file. Background/reference
# tier; prefer mini.test get_screenshot() for tests.
cmd_screenshot() {
  require_running
  local out="${1:-/tmp/ucw-screenshot.txt}"
  "$NVIM" --server "$SOCK" --remote-expr "luaeval('vim.api.nvim__screenshot(_A)', '$out')" >/dev/null
  echo "$out"
}

usage() {
  sed -n '2,40p' "$0"
  cat <<'EOF'

Commands:
  start [nvim-args...]   boot nvim (real config by default) in a detached tmux session
  stop                  kill the session and remove the socket
  send <keys>           inject Neovim-notation keys (':wq<CR>', '<C-w>v', ...)
  keys <tmux-keys>      inject raw tmux key events (C-c, ...)
  cmd <excmd>           run an ex command from normal mode
  expr <vimexpr>        evaluate a Vimscript expression and print it
  lua <chunk>           evaluate a Lua chunk (wrapped in a function) and print it
  capture               dump the screen as plain text
  capture-color         dump the screen with color/attr escapes
  messages              print :messages without blocking on hit-enter
  screenshot [path]     write nvim__screenshot to path (default /tmp/ucw-screenshot.txt)
EOF
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    start)          cmd_start "$@" ;;
    stop)           cmd_stop ;;
    send)           cmd_send "$@" ;;
    keys)           cmd_keys "$@" ;;
    cmd)            cmd_cmd "$@" ;;
    expr)           cmd_expr "$@" ;;
    lua)            cmd_lua "$@" ;;
    capture)        cmd_capture ;;
    capture-color|capturec) cmd_capture_color ;;
    messages)       cmd_messages ;;
    screenshot)     cmd_screenshot "$@" ;;
    ""|-h|--help|help) usage ;;
    *)              die "unknown command '$sub' (try: $0 --help)" ;;
  esac
}

main "$@"
