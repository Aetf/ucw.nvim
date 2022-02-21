# `ucw.nvim`

My experimental idea of managing neovim plugin dependencies and configs using concepts copied from systemd.

Mostly importantly, the following properties are implemented and can be used to control order and dependency:


* `requires`
* `wants`
* `requisite`
* `before`
* `after`

They share the same samentics as systemd units.
See [systemd.unit](https://www.freedesktop.org/software/systemd/man/systemd.unit.html) for details.

Additionally, `activation.wanted_by`/`activation.required_by` can be used, similar to `WantedBy`/`RequiredBy` in systemd
unit's `[Install]` section.

`activation.cmd` can be used to start a unit upon calling a command.

## Example

First, get a `nvimctl` instance:
```lua
_G.nvimctl = nvimd.setup {
  units_modules = {
    'ucw.units.thirdparty',
    'ucw.units.user',
  }
}
```
You can list the parent module containig unit definitions in `units_modules`.

Then start a target as needed:
```lua
if utils.is_gui() then
  nvimctl:start 'target.gui'
else
  nvimctl:start 'target.tui'
end
```

## Extra Features

### Workspace specific LSP settings
Load vscode-compatible settings file `.vscode/settings.json` for LSP.
