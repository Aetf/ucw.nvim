# `ucw.nvim`

My experimental idea of managing neovim plugin dependencies and configs using concepts copied from systemd.

Mostly importantly, the following properties are implemented and can be used to control order and dependency:


* `requires`
* `wants`
* `requisite`
* `before`
* `after`

They share the same semantics as systemd units.
See [systemd.unit](https://www.freedesktop.org/software/systemd/man/systemd.unit.html) for details.

Additionally, `activation.wanted_by`/`activation.required_by` can be used, similar to `WantedBy`/`RequiredBy` in systemd
unit's `[Install]` section.

* `activation.cmd` can be used to start a unit upon calling a command.

* `no_default_dependencies`

Unless `no_default_dependencies=true`, all targets gains a `after` dependency for all its `wants/requires/requisite`.
And all units gains a `after` dependency on `target.base`.

During activation,

* calls `unit.setup`
* calls `packadd`
* calls `unit.config`

## Example

Require `nvimd` and just boot from `init.lua`.

You can list the parent module containing unit definitions in `units_modules`.

```lua
local target = 'target.tui'
if utils.is_gui() then
  target = 'target.gui'
elseif vim.g.started_by_firenvim then
  target = 'target.firenvim'
end

require('nvimd').boot(
  {
    units_modules ={
      'ucw.units.thirdparty',
      'ucw.units.user',
    }
  },
  target
)
```

## Extra Features

### Workspace specific LSP settings

* Load vscode compatible settings file `.vscode/settings.json` for LSP.
* Load vscode compatible ltex dictionaries from `.vscode`.
