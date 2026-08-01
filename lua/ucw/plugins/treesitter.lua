-- Upstream's default branch is now `main`/`master` alike, both on the
-- rewritten API (no more `.configs.setup{}`, `ensure_installed`, or
-- `nvim_treesitter#foldexpr()` - those only exist on old, no-longer-tracked
-- history). This was discovered while migrating the engine (Phase 1), not a
-- deliberate modernization choice deferred to a later phase - the classic
-- API is simply no longer available from any live branch, so there was no
-- way to preserve it faithfully. Written against the new API per
-- nvim-treesitter's own current README.

local ensure_installed = {
  'bash',
  'beancount',
  'bibtex',
  'c', 'c_sharp', 'cmake',
  'comment', -- for todo, fixme, etc
  'cpp',
  'css',
  'cuda',
  'dart',
  'dockerfile',
  'dot',
  'fennel',
  'fish',
  'glsl',
  'go',
  'hjson',
  'html',
  'java',
  'javascript',
  'jsdoc',
  'json',
  'json5',
  'just',
  'llvm',
  'lua',
  'make',
  'markdown',
  'ninja',
  'nix',
  'perl',
  'php',
  'pug',
  'python',
  'regex',
  'rst',
  'ruby',
  'rust',
  'scss',
  'toml',
  'tsx',
  'typescript',
  'vim',
  'vimdoc', -- vim help files
  'vue',
  'yaml',
}

return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  priority = 1000,
  build = ':TSUpdate',
  dependencies = {
    { 'HiPhish/rainbow-delimiters.nvim', url = 'https://gitlab.com/HiPhish/rainbow-delimiters.nvim' },
  },
  config = function()
    require('nvim-treesitter').setup {}
    -- Parser compilation shells out to the `tree-sitter` CLI. Without it
    -- installed, .install() would otherwise retry (and fail, noisily) every
    -- single boot for every not-yet-compiled parser. Check once and skip
    -- with a single clear warning instead.
    if vim.fn.executable('tree-sitter') == 1 then
      require('nvim-treesitter').install(ensure_installed)
    else
      vim.notify(
        'tree-sitter CLI not found on $PATH - skipping treesitter parser install/update. '
        .. 'Install it (e.g. `cargo install tree-sitter-cli`) to get new/updated parsers.',
        vim.log.levels.WARN,
        { title = 'nvim-treesitter' }
      )
    end

    -- Additional parser
    vim.api.nvim_create_autocmd('User', {
      pattern = 'TSUpdate',
      callback = function()
        require('nvim-treesitter.parsers').openscad = {
          install_info = {
            url = "https://github.com/bollian/tree-sitter-openscad",
            files = { "src/parser.c" },
            branch = "master",
          },
        }
      end,
    })

    -- highlighting and indentation are natively provided by Neovim/this plugin
    -- now - just need to opt in per-buffer.
    --
    -- Folding is deliberately *not* set here. It was overwritten per-window by
    -- nvim-ufo in the full UI anyway, so this spec was a second, invisible
    -- source of fold state; the embedded contexts only got their folds from it
    -- by accident. Fold policy lives in ucw.options and ucw.plugins.ufo now.
    vim.api.nvim_create_autocmd('FileType', {
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
        pcall(function()
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end)
      end,
    })
  end,
}
