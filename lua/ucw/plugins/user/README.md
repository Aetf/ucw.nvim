# User overrides

Drop a file here with the same name as a file under `lua/ucw/plugins/` to
override/extend that plugin's spec. `lazy.nvim` merges multiple specs that
share the same plugin name/url across imported directories (this one is
imported after `ucw.plugins`, so entries here win).

Nothing lives here yet - this directory exists so the override pattern has
an obvious home when needed (e.g. a per-machine tweak).
