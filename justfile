set ignore-comments

# Everything that runs a binary runs it through the project's own environment,
# so `just`, the test child and a Neovim started from this directory all
# resolve the same pinned copies (mise.toml). `mise exec` installs a missing
# tool on the spot, which is why only `deps` has to be run deliberately.
# See docs/design/phase6.5-binary-deps.md §2.3.
mise := 'mise exec --'

# Unit tests
unit: (test "true" "unit")

# Integration tests
int: (test "true" "integration")

# All tests
all: (test "true")

# Run on ci, all tests are run and will not stop on error
ci: (test "false")

# Run tests
test stop_on_error *tags: deps
    @{{ mise }} nvim --headless --clean \
        --cmd 'let g:TestTags = "{{ tags }}"' \
        --cmd 'let g:TestExecuteStopOnError = v:{{ stop_on_error }}' \
        -u ./tests/aux/driver_init.lua \
        -S ./tests/aux/driver_run.lua

# Format this repo's Lua (stylua.toml)
fmt:
    @{{ mise }} stylua .

# Same, without writing.
# Red today, and that is not news: `stylua.toml` has existed unenforced for
# years and the repo is converting one `format_on_save` at a time
# (phase7-ci.md §1.4). The one reformat commit that makes this green is
# Phase 7's D3.
fmt-check:
    @{{ mise }} stylua --check .

# Static-check this repo's Lua.
# The rule set (`.luarc.json`: the globals, and the plugin library list that
# makes the check strong rather than merely quiet) is Phase 7's - phase7-ci.md
# §3.3/D9. Without it this runs against lua_ls's bare defaults, which do not
# even know `vim` is a global: 472 problems, ~20 of them real (§1.5 has them
# triaged). A tool to run, not yet a gate to pass.
lint:
    @{{ mise }} lua-language-server --check . --checklevel=Warning

# Drive a live nvim TUI for observation (see docs/tui-observation.md)
# e.g. `just tui start`, `just tui capture`, `just tui 'send' ':q<CR>'`, `just tui stop`
tui *args:
    @./scripts/tui-drive.sh {{ args }}

mini_dir := 'deps/mini.nvim'

# Install this project's dependencies: the pinned binaries (mise.toml) and the
# mini.test harness. No `mise trust` step: mise reads a config that is plain
# `[tools]` with literal versions without one, so a fresh checkout needs
# nothing authorized (measured on mise 2026.7.11 - see mise.toml).
#
# `deps/mini.nvim` is pinned to the *same* commit `lazy-lock.json` names for
# the runtime `mini.nvim` lazy.nvim installs. The two checkouts stay
# physically separate on purpose (the harness must not depend on the editor
# having booted), but there is no reason for them to be different revisions,
# and this way there is one pin rather than a second hand-written SHA that
# nothing would ever notice going stale. Bumping the runtime plugin now moves
# the test harness with it - that coupling is the point, and it is why the
# recipe *errors* when the entry is missing instead of falling back to
# `origin/main`: a silent fallback restores exactly the unpinnedness being
# removed here. See docs/design/phase7-ci.md §1.6/D10.
#
# There is no `update=true` any more. "Update the harness" is now spelled
# "update `mini.nvim` in `lazy-lock.json`", the same way every other pinned
# dependency of this repo is moved.
deps:
    #!/usr/bin/env bash
    set -euo pipefail
    mise install
    # `nvim` rather than `jq`: it is already a hard dependency of every recipe
    # here, and `vim.json.decode` reads the lockfile without adding a second one.
    if ! sha="$({{ mise }} nvim --headless --clean -c 'lua local ok, lock = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile("lazy-lock.json"), "\n")) end) local e = ok and lock["mini.nvim"] or nil if type(e) ~= "table" or type(e.commit) ~= "string" then vim.cmd("cquit 1") end io.write(e.commit)' -c qa)" || [[ -z "${sha:-}" ]]; then
        echo "just deps: lazy-lock.json has no usable 'mini.nvim' commit." >&2
        echo "  deps/mini.nvim takes its revision from there (phase7-ci.md §1.6)." >&2
        exit 1
    fi
    mkdir -p "{{ parent_directory(mini_dir) }}"
    if [[ ! -d "{{ mini_dir }}" ]]; then
        git clone \
            --depth 1 \
            --filter=blob:none \
            https://github.com/echasnovski/mini.nvim \
            "{{ mini_dir }}"
    fi
    if [[ "$(git -C "{{ mini_dir }}" rev-parse HEAD)" != "$sha" ]]; then
        # A shallow clone almost never has the pinned commit already; GitHub
        # serves a single-SHA fetch, so this stays a two-second operation
        # rather than an unshallow.
        git -C "{{ mini_dir }}" cat-file -e "$sha^{commit}" 2>/dev/null \
            || git -C "{{ mini_dir }}" fetch --depth 1 origin "$sha"
        git -C "{{ mini_dir }}" checkout --detach --quiet "$sha"
    fi
