# Test Setup

All tests are executed in two stages: driver and runner.

In the driver stage, the vim instance is initialized with
`tests/aux/driver_init.lua`.
The driver vim is the environment that executes all testing scripts
`test_*.lua`.
The driver instance has clean runtime path without any user config.
From there, the following three entries are added to the runtime path:

* suitable path to require `mini.test`.
* path to test helper (`tests/aux`).

In testing scripts, a second child vim instance is started with clean
state for each test case. This child instance has similar runtime path
sanitization, and only the following is added to the runtime path:

* the current working directory, which is assumed to be the top-level repo
  directory, such that in testing scripts you can directly require any modules
  defined in the repo for testing.
* suitable path to require `mini.test`.

## Unit test

Create new test suite with:
```lua
local H = require('helpers')
local T, child = H.new_unit_test()
```

## Integration test

Integration test is for testing the whole ucw.nvim config, so the child vim
instance is brought up with nvimd.
Full plugin is available and loaded.
Note that a temporary directory is used as data path so each run will go through
the installation process.

```lua
local H = require('helpers')
local T, child = H.new_integration_test()
```
