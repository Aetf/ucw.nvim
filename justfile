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
deps update="false":
    #!/usr/bin/env bash
    mise install
    mkdir -p "{{ parent_directory(mini_dir) }}"
    if [[ -d "{{ mini_dir }}" ]]; then
        if {{ update }}; then
            git -C "{{ mini_dir }}" fetch origin main
            git -C "{{ mini_dir }}" reset --hard origin/main
        fi
    else
        git clone \
            --depth 1 \
            https://github.com/echasnovski/mini.nvim \
            "{{ mini_dir }}"
    fi
