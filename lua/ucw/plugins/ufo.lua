local function fold_virt_text_handler(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local suffix = ('  %d '):format(endLnum - lnum)
  local sufWidth = vim.fn.strdisplaywidth(suffix)
  local targetWidth = width - sufWidth
  local curWidth = 0
  for _, chunk in ipairs(virtText) do
    local chunkText = chunk[1]
    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
    if targetWidth > curWidth + chunkWidth then
      table.insert(newVirtText, chunk)
    else
      chunkText = truncate(chunkText, targetWidth - curWidth)
      local hlGroup = chunk[2]
      table.insert(newVirtText, { chunkText, hlGroup })
      chunkWidth = vim.fn.strdisplaywidth(chunkText)
      -- str width returned from truncate() may less than 2rd argument, need padding
      if curWidth + chunkWidth < targetWidth then
        suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
      end
      break
    end
    curWidth = curWidth + chunkWidth
  end
  table.insert(newVirtText, { suffix, 'MoreMsg' })
  return newVirtText
end

local utils = require('ucw.utils')
local au = require('au')

local function ufo_color()
  utils.highlight.UfoFoldedBg = 'IncSearch'
end

-- Can ufo's treesitter provider actually fold this filetype?
--
-- Two things have to hold, and both are checked against the running Neovim
-- rather than against a list:
--
-- 1. A parser must load. Deliberately not "is it listed in treesitter.lua's
--    `ensure_installed`": that list is a declaration of intent, and a declared
--    parser is not a compiled one on any machine - the install is asynchronous,
--    it only runs in a full-UI session at all
--    (docs/design/phase6.5-acceptance-review.md R1), individual grammars fail
--    to build, and a `tree-sitter` CLI has to be resolvable before any of it
--    happens. Asking the running Neovim is the only answer that is true here
--    and now. (An earlier version of this comment argued the point from "this
--    machine has no `tree-sitter` CLI", which stopped being true before anyone
--    noticed - docs/design/phase6.5-binary-deps.md §3.3 is what found that, and
--    is the reason the durable reason is stated instead.) Note `language.add`
--    returns `nil, err` instead of raising, so the return value is what has to
--    be tested - a `pcall` around it always succeeds.
-- 2. A `folds` query must exist. `ufo/provider/treesitter.lua` raises
--    UfoFallbackException without one, and that exception has nowhere to go:
--    ufo consults exactly two providers, and a raise from the *second* one
--    escapes the whole promise chain (`ufo/provider/init.lua` calls the
--    fallback inside the main provider's rejection handler, unguarded). The
--    buffer ends up with no folds at all and an UnhandledPromiseRejection in
--    `:messages`.
--
-- Getting (2) wrong is not hypothetical: `vimdoc` is one of the parsers
-- bundled with Neovim and ships no `folds.scm`, so editing any plugin's
-- `doc/*.txt` hit exactly this. Of the languages in `ensure_installed`,
-- dockerfile, json5, llvm, pug, rst and openscad are in the same position.
--
-- This looks at the host language only. ufo raises only when *no* tree in the
-- buffer has a fold query, so a host language without one whose injections
-- have one would still fold; those pick `indent` here instead.
local function has_parser(filetype)
  local lang = vim.treesitter.language.get_lang(filetype)
  if lang == nil or vim.treesitter.language.add(lang) ~= true then
    return false
  end
  return #vim.treesitter.query.get_files(lang, 'folds') > 0
end

-- ufo's default is `{'lsp', 'indent'}` (ufo/fold/manager.lua), and it only ever
-- consults providers[1] and providers[2] - so with the default its treesitter
-- provider is unreachable, and every filetype without a configured LSP server
-- folds by indentation. Measurably worse: on an 11-line vimscript file the
-- indent provider gave one flat fold over the first function, no nesting for
-- the block inside it, and no fold at all for the second function, where
-- treesitter got all three right.
--
-- Preferring treesitter also makes the two halves of this config agree: a
-- buffer without LSP now folds by treesitter here *and* in firenvim/vscode,
-- where folds come from `vim.treesitter.foldexpr()` (see ucw.options).
--
-- The buftype gate is the same providers[2] trap as the fold query above, found
-- the same way and one level further out: ufo's treesitter provider raises
-- UfoFallbackException for `nofile` too, and its LSP provider rejects with the
-- same exception for `nofile`, so both bail and the raise escapes. ufo attaches
-- on BufWinEnter, floating windows included, so this fired on every `K` - the
-- hover float is `nofile` with `filetype=markdown`, which does have a parser and
-- a fold query. Only '' and 'acwrite' reach either provider's real code path;
-- for every other buftype treesitter returns nothing at all, so indent is the
-- only provider that can answer, which is also what the pre-Phase-4 default did.
local function provider_selector(_, filetype, buftype)
  if buftype ~= '' and buftype ~= 'acwrite' then
    return { 'lsp', 'indent' }
  end
  return has_parser(filetype) and { 'lsp', 'treesitter' } or { 'lsp', 'indent' }
end

local function config()
  -- UFO uses manual folding that unforunately doesn't play well with small foldlevel
  -- TL'DR is vim will immediately close all folds to foldlevel whenever manual folding
  -- is updated, which UFO does a lot, notably at InsertLeave.
  -- See https://github.com/kevinhwang91/nvim-ufo/issues/7
  --
  -- Concretely, in ufo/fold/driver.lua every fold update erases all folds
  -- (`zE`), recreates each range with `:fold`, and then restores 'foldlevel' -
  -- and assigning 'foldlevel' closes every fold deeper than it. So this is a
  -- structural requirement of the manual-fold model rather than a preference,
  -- and it is why ucw.options only sets 'foldlevel' for the contexts where ufo
  -- is *not* loaded. Do not "clean it up".
  vim.opt.foldlevel = 99
  vim.opt.foldlevelstart = 99 -- useful when switching from a window with small foldlevel

  -- Using ufo provider needs remap 'zR' and 'zM' to not let them change foldlevel
  vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
  vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)

  -- Tell any server that we support foldingRange.
  --
  -- This used to go through `ucw.lsp.register_on_server_setup`, a hook
  -- monkey-patched onto lspconfig's setup path - which servers stopped taking
  -- once they came up through native `vim.lsp.enable()`, so folding capability
  -- had silently not been advertised to anyone. `vim.lsp.config('*')` is the
  -- native lowest-priority layer, and capabilities is a table, so this merges
  -- with blink.cmp's contribution instead of replacing it.
  --
  -- Ordering matters and is load-bearing: every '*' capability contributor has
  -- to run before the first `vim.lsp.enable()`. This spec is eager and LSP is
  -- `ft`-triggered, so startup strictly precedes it; tests/test_lsp.lua asserts
  -- the merged result rather than trusting that.
  vim.lsp.config('*', {
    capabilities = {
      textDocument = {
        foldingRange = {
          dynamicRegistration = false,
          lineFoldingOnly = true,
        },
      },
    },
  })

  require('ufo').setup {
    -- timeout in ms to highlight the range when opening the folded line, 0 to disable
    -- keep this the same as highlight on yank
    open_fold_hl_timeout = 200,
    fold_virt_text_handler = fold_virt_text_handler,
    provider_selector = provider_selector,
  }

  ufo_color()
  au.group('ufo-color', {
    { 'ColorScheme', '*', ufo_color },
  })
end

return {
  'kevinhwang91/nvim-ufo',
  cond = require('ucw.targets').is_full_ui,
  dependencies = { 'kevinhwang91/promise-async' },
  config = config,
}
