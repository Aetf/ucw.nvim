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

# Same, without writing. This is the `format` CI job.
fmt-check:
    @{{ mise }} stylua --check .

# Install any plugin `lazy-lock.json` names that is not on disk yet, at the
# commit it names. A no-op on a machine that has opened this config; on a bare
# runner it is what gives `lint` something to resolve `require('snacks')`
# against. `install` rather than `restore` on purpose - restore would also drag
# an already-installed plugin *back* to the lockfile, which is a thing to do
# deliberately from the editor and not a side effect of running a linter.
plugins:
    @{{ mise }} nvim --headless '+Lazy! install' +qa

# Static-check this repo's Lua. This is the `lint` CI job.
#
# Three things have to be true for this to be the check phase7-ci.md §1.5
# measured, and each of them fails *quietly* when it is not - the whole
# §5 risk of this phase is that a weaker lint config looks identical to a
# working one. So each is arranged here and each is loud when it cannot be:
#
#  1. `$VIMRUNTIME` must be set. It is exported by Neovim to its own child
#     processes and by nothing else, so a shell does not have it; without it
#     `.luarc.json`'s library entry silently evaporates and the check runs with
#     no Neovim annotations at all (measured: 31 problems instead of 18, and
#     *fewer* of them real). Asked of `nvim` rather than hard-coded, so
#     whichever Neovim is on PATH is the one checked against.
#  2. The plugins must be installed (`plugins` above), and their `lua/` dirs
#     must reach `workspace.library` (`scripts/luarc-lint-config.lua`).
#  3. `runtime.pathStrict` must be on, which is `.luarc.json`'s job - see the
#     comment there. It is checked in so the editor gets it too.
#
# See phase7-ci.md §1.5a/§1.5b/§3.3, D9/D11.
lint: plugins
    #!/usr/bin/env bash
    set -euo pipefail
    # `io.write` rather than `:echo`: headless `:echo` goes to *stderr*, so the
    # obvious spelling captures an empty string and hands the check a config
    # with the runtime library silently missing. The guard below caught exactly
    # that on the first run of this recipe.
    VIMRUNTIME="$({{ mise }} nvim --headless --clean -c 'lua io.write(vim.env.VIMRUNTIME or "")' -c qa)"
    if [[ -z "$VIMRUNTIME" || ! -d "$VIMRUNTIME/lua" ]]; then
        echo "just lint: no usable \$VIMRUNTIME from nvim (got '${VIMRUNTIME:-}')." >&2
        echo "  Without it this checks the repo with none of Neovim's annotations" >&2
        echo "  and still exits 0 on a good day - see phase7-ci.md §1.5b." >&2
        exit 1
    fi
    export VIMRUNTIME
    {{ mise }} nvim --clean -l scripts/luarc-lint-config.lua .luarc.json .luarc.lint.json
    {{ mise }} lua-language-server --check . --checklevel=Warning --configpath=.luarc.lint.json

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
