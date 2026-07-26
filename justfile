set ignore-comments

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
    @nvim --headless --clean \
        --cmd 'let g:TestTags = "{{ tags }}"' \
        --cmd 'let g:TestExecuteStopOnError = v:{{ stop_on_error }}' \
        -u ./tests/aux/driver_init.lua \
        -S ./tests/aux/driver_run.lua

# Drive a live nvim TUI for observation (see docs/tui-observation.md)
# e.g. `just tui start`, `just tui capture`, `just tui 'send' ':q<CR>'`, `just tui stop`
tui *args:
    @./scripts/tui-drive.sh {{ args }}

mini_dir := 'deps/mini.nvim'

# Install mini.test dependency
deps update="false":
    #!/usr/bin/env bash
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
