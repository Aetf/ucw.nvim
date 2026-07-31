-- Auto-insert matching brackets/quotes.
--
-- Used to be smuggled in as a `dependencies` entry of nvim-cmp, which it never
-- belonged to - it is not a completion plugin. The one thing that genuinely
-- tied them together was a `confirm_done` handler that added brackets after
-- accepting a function completion; blink.cmp does that itself via
-- `completion.accept.auto_brackets` (on by default), so the bridge is gone
-- and this stands on its own.
return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter',
  opts = {
    check_ts = true,
    enable_check_bracket_line = true,
  },
}
