-- Markdown. Replaces zeta-note, which its own author retired in favour of
-- marksman.
--
-- The primary use is an Obsidian vault, where wiki-links and backlinks are
-- only meaningful across the whole vault - but a vault has a `.obsidian/`
-- directory and usually no `.git`, so upstream's markers
-- (`.marksman.toml`, `.git`) never match and every note would come up in
-- single-file mode.
--
-- `.git` has to be repeated here: list-valued fields are replaced wholesale by
-- the higher layer, not appended to (measured - see
-- docs/design/phase3-lsp-redesign.md §2). The inner table is one priority
-- tier: a vault marker beats a `.git` further up.
--
-- A standalone .md file still matches nothing and falls back to single-file
-- mode, which keeps heading/link completion and diagnostics within the file.
return {
  root_markers = { { '.marksman.toml', '.obsidian' }, '.git' },
}
