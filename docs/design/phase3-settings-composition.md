# Phase 3 follow-up design: who composes `client.settings`

Status: **revision 3 — built, verified.** §9 records what shipped and every
verification result. Supersedes the "Implementation
notes" paragraph of `phase3-lsp-redesign.md` §5 (".vscode/settings.json: unify
onto `LspAttach`") and replaces the `User UcwLspSettingsReloaded` mechanism that
the acceptance review's P2 fix introduced.

**Revision 2 reverses revision 1's design after review.** r1 proposed a generic
settings-layer registry (`ucw.lsp.settings` with a `LAYERS` list and a
`fun(client, acc) -> acc` transform signature). The objection that killed it:
the ltex dictionary files are not a *second, independent* source of settings —
they are **part of the `.vscode/` settings themselves**, by the very convention
that gave them their names (§2b, researched). A layer registry is the right
answer to "two independent writers"; there are not two. r1's measurements all
survive and are kept; only §3-§5 changed. r1's design is retained in §4 as
option D, because it is the fallback if the premise ever stops holding.

Scope: one slot — `vim.lsp.Client.settings` — and the two modules that write it.
Nothing else in the Phase 3 design is touched: `servers.lua` stays the single
registration point, `after/lsp/` stays table-only, activation stays `ft`-driven.

Same rule as every design document here: everything marked **measured** was
produced on this machine, Neovim 0.12.3, against the real config, with real
language servers where the claim is about a server. Where an earlier claim turned
out to be wrong under measurement, it is marked **[corrected]** rather than
quietly dropped.

---

## 1. What is actually running today

Two modules write `client.settings`, and they write it in incompatible ways:

| writer | when | how | composes? |
|---|---|---|---|
| `ucw.lsp.vscode` | `LspAttach`, then every `.vscode/settings.json` change | `merged = deepcopy(st.base)` + files, then **assigns** `client.settings = merged` (`vscode.lua:81-94`) | no — the assignment discards everyone else |
| `ucw.lsp.ltex_dict` | `LspAttach`, then after each `_ltex.*` command | reads `client.settings` as its base and **mutates in place** (`ltex_dict.lua:96-102`) | yes — never overwrites anyone |

`st.base` is a snapshot taken at attach, *before* `ltex_dict` has run. So every
`.vscode/settings.json` edit rebuilt the settings from a base that never had the
dictionaries in it and assigned the result over them. That is P2, and it is
**synchronous and deterministic** — there is no race. Both `LspAttach` handlers
run inside the same autocmd dispatch, in registration order (`ucw.lsp.attach` is
registered at boot, `ltex_dict` from nvim-lspconfig's `config`).

The current fix is an announcement: `vscode.reload` fires
`User UcwLspSettingsReloaded` after it pushes, and `ltex_dict` re-applies its
layer on top. It works — but it is the only private cross-module API Phase 3
has, it has to be remembered (hence the AGENTS.md line), and it costs extra
round trips.

### Measured cost of the announcement

Real `ltex-ls-plus`, a vault with both `.vscode/settings.json` and
`.vscode/ltex.dictionary.en-US.txt`, payloads snapshotted **synchronously inside
`client.rpc.notify`**:

| event | `ltex.language` | `ltex.dictionary` |
|---|---|---|
| PULL (`workspace/configuration`) | en-US | orloj |
| PULL | en-US | orloj |
| *(rewrite `settings.json` to en-GB)* | | |
| **PUSH (wire)** | en-GB | **`<MISSING>`** |
| **PUSH (wire)** | en-GB | orloj |
| PULL | en-GB | orloj |

One `settings.json` edit produces **two** `didChangeConfiguration`
notifications, the first of which really does put the un-learned settings on the
wire. With an in-process fake client the same shape appears at attach: **three**
pushes, the first without the dictionary, and the third an exact duplicate of the
second. Counting the one Neovim sends itself (§2), a real ltex sees **four**
pushes to open one file.

### [corrected] What that transient does *not* cost

The second-round review claimed the server "briefly runs with the dictionary
removed". **Measured, that is not what happens for ltex**: the PULL rows above
show the server reads `client.settings` *after* both pushes and gets the correct
table every time. ltex-ls-plus is a pull-model server (§2), so the payload it is
handed is inert. The real cost is the redundant pushes — each one makes the
server re-pull and re-check every open document — not a wrong state it acts on.

The reason to restructure is therefore **composition correctness and the absence
of a contract**, not "wrong bytes on the wire". Stated plainly so the motivation
is not oversold.

### [corrected] One thing that is *not* broken

`vim.lsp.config[name]` returns the **same cached table** on every access
(measured: `rawequal` is true across two lookups, including `.settings`), and
`client.lua:409` initialises `client.settings` from `config.settings`. That looks
like `ltex_dict`'s in-place mutation should leak a project's dictionary into the
shared config and from there into every later client. **Measured: it does not** —
in a vault with a dictionary file and no `settings.json` (so `vscode.reload`
early-returns and never replaces the table), `client.settings.ltex.dictionary` is
`{ ["en-US"] = { "orloj", "hradcany" } }` while
`vim.lsp.config['ltex_plus'].settings.ltex.dictionary` is still `nil`, and
`rawequal(client.settings, vim.lsp.config['ltex_plus'].settings)` is `false`.
Recorded so nobody re-derives the scare.

### One thing that *is* broken, found while measuring

`ltex_dict.get_settings_dir` calls `mkdir({ parents = true, exists_ok = true })`
on the **read** path (`ltex_dict.lua:48`). **Measured**: opening a markdown file
in a project that has no `.vscode/` leaves one behind —

```
before: { ".obsidian", "note.md" }
after:  { ".obsidian", ".vscode", "note.md" }
```

Empty, unasked, in every project that ever opened a prose file. The design below
removes it for free (directories are created when something is written, not when
something is looked for); noted here so it is not mistaken for a side effect of
the rewrite.

---

## 2. What the native framework actually guarantees

### Push and pull are two different contracts

* `client.lua:601` — Neovim **itself** sends one
  `workspace/didChangeConfiguration` right after `initialize` if
  `next(client.settings)` is non-empty. Every server whose `after/lsp/` or
  upstream config carries `settings` already gets one push before any of our
  code runs.
* `handlers.lua:218-249` — the default `workspace/configuration` handler reads
  **`client.settings` at request time** (`:235`). `client.lua:133` documents the
  field the same way: *"Sent to the LS if requested via
  `workspace/configuration`"*. For a pull server, `didChangeConfiguration` is
  only a "come and re-read" signal; the payload does not matter.

Which of our servers pull, measured by counting `workspace/configuration`
requests over one session that opens a file of each language:

| server | pulls | pushes received |
|---|---|---|
| `basedpyright` | 6 | 1 |
| `ltex_plus` | 3 | 3 |
| `texlab` | 2 | 1 |
| `taplo` | 1 | 0 |
| `lua_ls` | **0** | 2 |
| `ruff`, `clangd`, `marksman` | 0 | 0 |

So a design cannot rely on pull semantics to paper over composition: `lua_ls` is
push-only.

### `LspNotify` is native, and is the wrong tool here

`client.lua:830-851`: `Client:notify` fires `LspNotify` for every notification,
with `data = { client_id, method, params }`. Core consumes it itself
(`inlay_hint.lua:266`, `diagnostic.lua:450`, `_folding_range.lua:231`). It is a
literal native replacement for the custom `User` event. Three measured reasons it
does not help:

1. It is `vim.schedule`d, so a subscriber re-applies strictly *after* the wire
   push — it can only ever patch up, never prevent.
2. `params` travels **by reference**. Measured: an `LspNotify` observer reading
   `ev.data.params.settings` sees the table as it looks one tick later, i.e.
   after `ltex_dict` mutated it in place — the first probe of this design
   reported "the dictionary was in the payload" and was wrong for exactly this
   reason. (Recorded because it also means `LspNotify` cannot be used to audit
   what a server was told; the table above was produced by wrapping
   `client.rpc.notify` instead.)
3. A subscriber that re-applies and re-notifies re-enters its own handler, so it
   needs an idempotence guard the custom event does not need.

### `vim.tbl_deep_extend` replaces nested lists

Measured: `vim.tbl_deep_extend('force', {a={1,2,3}}, {a={9}})` → `{a={9}}`, and
for the shape that matters,
`{ltex={dictionary={['en-US']={'a','b'}}}}` merged with
`{ltex={dictionary={['en-US']={'c'}}}}` → `{['en-US']={'c'}}`. (Top level is the
exception — the two tables are always walked key-wise, so `{1,2,3}` + `{9}` gives
`{9,2,3}`; irrelevant here, noted so the rule is not mis-stated.)

So whoever merges a sidecar file into a settings key **cannot** do it with
`tbl_deep_extend` — a declared `ltex.dictionary` in `settings.json` and the words
in `ltex.dictionary.en-US.txt` have to be unioned explicitly, which is what
`read_prop` does today via `prop_get_table` + `tbl_insert_uniq`
(`utils.lua:178-186`, `:203-207`).

## 2b. What the `.vscode/ltex.*.txt` convention actually is

This is the fact revision 1 did not have, and it is what makes the simpler design
possible. From the LTeX+ VSCode extension's own documentation:

* **Implicit default files are read automatically**, with no reference from
  `settings.json` at all:
  > `LTEX_GLOBAL_STORAGE_PATH/ltex.SETTING.LANGUAGE.txt`, …
  > `WORKSPACE/.vscode/ltex.SETTING.LANGUAGE.txt`, …
  > `WORKSPACE_FOLDER/.vscode/ltex.SETTING.LANGUAGE.txt`
* **Explicit references exist too**: a list entry beginning with `:` names an
  external file — *"Each line of the file will be implicitly inserted as an entry
  into the value of the setting at the position where you specify the external
  file."* Relative paths resolve **against the `.vscode` directory the setting was
  written in**; a leading `~` is the home directory.
* **`addToDictionary` picks the destination the same way**: *"pick the first
  entry that explicitly specifies an external file (i.e. the first entry starting
  with `:`). If there is no such entry, the implicit default path is used."*
* The resolution is **client-side**. `ltex-ls-plus` itself does not do it —
  ltex-plus/ltex-ls-plus#56 ("`ltex.dictionary` does not accept an external
  file") is open and labelled *enhancement*. So a client that wants this has to
  implement it, which is exactly what the VSCode extension does.

Two consequences:

1. `ltex_dict.lua`'s docstring claim — *"the same on-disk layout VSCode's ltex
   extension uses … so a project's `.vscode/` directory works in both editors"* —
   is **accurate**, and this config already implements the *implicit default
   path* half of the convention. It does not implement the `:` half.
2. **The dictionary files are `.vscode` settings.** They are not a second source
   that happens to live nearby; they are the file-backed spelling of three keys
   of the same settings object, defined by the same vendor convention as
   `settings.json` itself. Which means the module that owns "compute this
   client's settings from its `.vscode/` directory" should own them, and there is
   no second writer to compose with.

Sources: <https://ltex-plus.github.io/ltex-plus/vscode-ltex-plus/setting-scopes-files.html>,
<https://github.com/ltex-plus/ltex-plus/blob/develop/pages/vscode-ltex-plus/setting-scopes-files.md>,
<https://github.com/ltex-plus/ltex-ls-plus/issues/56>.

---

## 3. The problem, restated

Revision 1 said: *one mutable slot, two writers, one of which needs delete
semantics.* Half of that is wrong. There are not two writers of settings — there
is one settings composer (`vscode.lua`) and one module that happens to write
**files** that the composer should have been reading (`ltex_dict.lua`).

The delete-semantics half stands and is why the base snapshot exists:
`vscode` must rebuild from a fixed base, or a key removed from `settings.json`
would never go away. **The snapshot is not the bug. The bug is that a second
module reached into the result after the rebuild instead of contributing an
input to it.**

---

## 4. Options

| | shape | verdict |
|---|---|---|
| **A** | keep `User UcwLspSettingsReloaded` | works; one private API to remember, N+1 pushes per change, and every future writer must learn the contract |
| **B** | swap it for native `LspNotify` | strictly less private API, but §2: schedule-delayed, by-reference, re-entrant. Replaces the name, not the mechanism, and forecloses fixing the redundant pushes |
| **C** | rely on `workspace/configuration` | not ours to choose, and `lua_ls` measured 0 pulls |
| **D** | generic layer registry (`ucw.lsp.settings`, `fun(client, acc) -> acc`) | revision 1's choice. Correct, but solves "N independent writers" when N is 1 — a new module, a new signature and a new ordering rule to buy generality nothing is asking for. **Kept as the fallback** if a future contributor genuinely is not a `.vscode/` file |
| **E** | **one owner, sidecar files as data** | chosen — §5 |

---

## 5. Design: `ucw.lsp.vscode` owns the whole `.vscode/` directory

`ucw.lsp.vscode` already means "this client's settings, as configured by the
project's `.vscode/` directory". The change is to make that true of the whole
directory instead of one file in it.

### The extension point

One table. A settings key listed here may additionally be backed by a sibling
`<key>.<variant>.txt`, whose non-empty lines are unioned into
`settings[<key>][<variant>]`:

```lua
-- lua/ucw/lsp/vscode.lua
--
-- Settings keys that may also be written as sibling text files, one per
-- variant: `<dir>/ltex.dictionary.en-US.txt` contributes its lines to
-- `settings.ltex.dictionary['en-US']`, unioned with whatever settings.json
-- declared for the same key.
--
-- This is not an invention: it is the implicit-default-path half of VSCode
-- LTeX's own convention (see docs/design/phase3-settings-composition.md §2b),
-- which is why a `.vscode/` written by this config is readable by VSCode and
-- vice versa. The mechanism is key-agnostic; the list is data.
local SIDECAR_KEYS = {
  'ltex.dictionary',
  'ltex.hiddenFalsePositives',
  'ltex.disabledRules',
}
```

That list is today's `ltex_dict.PROPS`, relocated and spelled as full dotted
keys. No behaviour changes; what changes is who reads it.

### Composition, in one function

```lua
---@param client vim.lsp.Client
---@return boolean changed
function M.reload(client)
  local acc = vim.deepcopy(base[client.id] or client.settings or {})
  for _, dir in ipairs(M.settings_dirs(client)) do
    local obj = M.load(dir .. '/settings.json')          -- workspace dirs only
    if obj then acc = vim.tbl_deep_extend('force', acc, obj) end
    read_sidecars(acc, dir)                              -- union, per §2's list rule
  end
  if vim.deep_equal(acc, client.settings) then return false end
  client.settings = acc
  client:notify('workspace/didChangeConfiguration', { settings = acc })
  return true
end
```

* **`settings_dirs(client)`** — the global store first, then one `.vscode/` per
  workspace folder. Later directories win, mirroring VSCode's user →
  workspace → workspace-folder scope order. It **does not** `mkdir`: that is the
  side effect measured in §1, and creation belongs on the write path.
* **The base stays an attach-time snapshot**, not `vim.lsp.config[name].settings`.
  The native lookup is measured correct for four of our servers (`client.settings`
  deep-equals `vim.lsp.config[name].settings` at start for `lua_ls`,
  `basedpyright`, `ruff`, `texlab`) but `vim.lsp.config['rust-analyzer']` is
  **`nil`** (measured) — rustaceanvim starts its client outside `vim.lsp.enable`,
  and that client is precisely what this path covers "for free". A snapshot works
  for every client.
* **Sidecars union, `settings.json` deep-extends.** Two different merges on
  purpose: §2's measurement says a nested list is replaced wholesale, and a
  dictionary must not be. Because both merges now live inside one function, this
  is an implementation detail with a test, not a contract another module has to
  honour.
* **Push only when the result changed.** This is what collapses the measured
  4-pushes-per-attach and 2-pushes-per-edit to one each; the composition is
  idempotent, so a recompute that changes nothing says nothing. Same guard core
  uses at `client.lua:601`.

### What `ltex_dict` becomes

It stops being a settings writer and becomes what it always was underneath: the
handler for three off-spec server commands that **write files**.

* keeps `M.commands` and `write_prop`, and `lu.locate_root_for_doc` to choose
  which directory to write into;
* asks `vscode` for the target directory (`M.settings_dirs`) and creates it
  **at write time**;
* ends each command with `require('ucw.lsp.vscode').reload(client)`;
* **loses**: `reload`, `load_dicts`, `read_prop`, `PROPS`, both autocmds (the
  `LspAttach` one and the `User UcwLspSettingsReloaded` one), and every reference
  to `client.settings`.

`ucw.lsp.vscode` loses the `nvim_exec_autocmds('User', ...)` block and `st.files`
(derivable from `client.workspace_folders`); the only per-client state left is
the base snapshot and the watchers.

> **Superseded on the watchers** by `phase9.5-trial-period.md` T8: they are keyed
> by settings directory and shared by every client that reads it, so per-client
> state is the base snapshot alone, and one directory change is one notification.

`AGENTS.md` loses "anything writing `client.settings` re-applies on
`UcwLspSettingsReloaded`" and gains "`ucw.lsp.vscode` is the only writer of
`client.settings`; a file that contributes to settings is a sidecar key, not a
second writer".

### Deliberately not included

**The `:`-prefix explicit reference syntax** (§2b). It is the other half of the
convention, it is ~15 lines (`:` entries in a list are replaced in place by the
file's lines; relative to the `.vscode` dir; `~` expanded), and it would make the
`SIDECAR_KEYS` allow-list unnecessary for anything that opts in explicitly. It is
not needed for parity — this config has never had it — and it is a feature, not a
refactor. Recorded with its exact semantics so it can be added later without
re-reading the vendor docs.

**Watching the sidecar files.** Only `settings.json` is watched today, so editing
a dictionary file by hand needs a restart. With one composer, adding the sidecars
to the watch list is trivial, but it is a behaviour change; out of scope.

---

## 6. Verification plan

Every new test is checked in reverse — revert its fix, exactly that test goes
red — per the standing rule in `docs/testing.md`.

* **Composition** (keep the existing P2 case): a `settings.json` reload keeps the
  ltex dictionary. Should pass unchanged, now for a structural reason.
* **Deletion semantics — new, and currently untested anywhere.** Remove a key
  from `settings.json`; it must disappear from `client.settings`. This is what
  the base exists for, and nothing asserts it today, so the rewrite could
  silently regress it.
* **Union semantics — new.** A `settings.json` declaring
  `ltex.dictionary['en-US'] = {'declared'}` plus a `.txt` containing `orloj` must
  yield both, in that order. This is the case §2's list-replacement measurement
  says a naive `tbl_deep_extend` would break.
* **Push count — new.** With a fake client, one `settings.json` edit produces
  exactly **one** `workspace/didChangeConfiguration`, and an attach that changes
  nothing produces **none**. Snapshot the payload inside `rpc.notify`, not from
  `LspNotify` (§2).
* **No directory is created by reading — new.** Open a prose file in a project
  with no `.vscode/`; the project is unchanged afterwards (§1's measurement,
  turned into a regression test).
* **`_ltex.addToDictionary` still round-trips**: writes into the project's
  `.vscode/`, creating it, and the word reaches `client.settings` — the existing
  `T['ltex']` case, plus an assertion that the directory was created *by the
  write*.
* **Every client still covered**: the existing "handlers fire for a client
  started outside `vim.lsp.enable`" case must still see `.vscode` settings
  applied — the rustaceanvim path, and why the base is a snapshot.
* **Real TUI**: an Obsidian-shaped vault with real `ltex-ls-plus`; add a word via
  `_ltex.addToDictionary`, then edit `settings.json`; the word survives, the
  language changes, and `rpc.notify` is called once per change.

## 7. Risks

* **The premise is that every settings contributor is a `.vscode/` file.** True
  today, and true of the convention this config follows. If a future contributor
  is not — settings that must be computed, say — option D is the fallback and
  this design does not block it: `reload` grows a list of inputs instead of a
  list of directories.
* **`base` is per client id and needs the same `LspDetach` teardown the watchers
  got** (acceptance review P5), or it leaks a table per restarted client. Cheap,
  but it is the same trap in a new place — worth the test P5 never had.
* **Two merge rules in one function** (deep-extend for `settings.json`, union for
  sidecars) is a thing to get wrong. It is why §6 asserts both directly rather
  than only asserting the end state.
* **This does not remove the push Neovim itself sends** at `client.lua:601` —
  that one is core's, carries the static settings, and is correct.

## 8. Out of scope

Deliberately not folded in, so this change stays reviewable on its own:

* `ucw.lsp.vscode`'s `vim.lsp.get_buffers_by_client_id()`, deprecated for removal
  in 0.13 (second-round review Q1) — a one-line swap to
  `vim.lsp.get_client_by_id(id).attached_buffers`.
* The dead `trouble.nvim` branch in `keys/actions.lua` (Q4).
* The two undocumented `:checkhealth vim.lsp` warnings (Q3).
* **[r3] The watcher gap found while verifying this change** (Q6, §9). It is a
  watcher-lifetime bug, not a composition one, and it predates this work.

---

## 9. [r3] As built

Shipped as designed. `ucw.lsp.vscode` gained `SIDECAR_KEYS`, `global_dir`,
`workspace_dir`, `settings_dirs`, `sidecar_path`, `read_sidecars` and a public
`reload` returning whether anything changed; it lost `locate_settings_file`,
`st.files` and the `User UcwLspSettingsReloaded` block. `ucw.lsp.ltex_dict` went
from 174 lines to 88 and no longer mentions `client.settings`, `LspAttach` or
plenary — it writes files and calls `vscode.reload`. `M.setup()` went with it, so
`lua/ucw/plugins/lspconfig.lua`'s `config` is one line again. `AGENTS.md`'s
"if you write `client.settings`, you are not the only one" invariant is replaced
by "`ucw.lsp.vscode` is the only writer".

One deviation from §5: `M.attach` no longer returns early for single-file
clients. It has to compose the user-scope directory for them — that is where a
word added without a project goes — and the push-when-changed guard is what keeps
that silent. `is_watching` therefore means "has running watchers" rather than
"has state", which is what its one existing test already asserted.

### Suite

92 → **97 cases**, green twice. Every new case verified in reverse — the fix it
covers reverted, exactly that case goes red:

| new case | broken by | went red |
|---|---|---|
| a workspace with no `.vscode` is silent | removing the `deep_equal` push guard | ✓ (with *single-file clients are left alone*) |
| …and no directory was created by reading | restoring the read-path `mkdir` | ✓ |
| a key removed from `settings.json` disappears | composing from `client.settings` instead of `st.base` | ✓ |
| sidecar entries are unioned with declared ones | replacing the list instead of unioning | ✓ |
| sidecar files apply without a `settings.json` | only reading sidecars when a `settings.json` applied | ✓ (with the `ltex` command case) |

*(`each change is pushed exactly once` is the fifth new case; it pins the count
that the announce-and-re-apply design inflated, and is covered in reverse by the
guard row above.)*

### Real `ltex-ls-plus`, end to end

Obsidian-shaped vault, no `.vscode/` to start with, `rpc.notify` wrapped
synchronously:

| step | result |
|---|---|
| open `note.md`, client attaches | project still `{ .obsidian, note.md }` — **the read created no `.vscode/`** |
| `_ltex.addToDictionary` `orloj` | `.vscode/ltex.dictionary.en-US.txt` written; `client.settings…dictionary = orloj`; **1** push |
| two no-op `reload()` calls | **0** pushes for the second; the first legitimately picked up a `settings.json` written earlier in the probe |

A/B against the pre-change tree for the directory claim: same vault, same steps,
`.vscode created by the read path: true` before, `false` after.

### [r3] Q6 — a watcher gap this verification exposed

Writing `.vscode/settings.json` into an **already open** project is never picked
up. `utils.FileWatcher` starts `uv.fs_event_start` on the file, which fails
silently when the file does not exist, and nothing retries.

**Measured on both trees** — `settings.json created after attach -> reload
landed: false` before this change and after — so it is pre-existing, not a
regression, and the read-path `mkdir` that used to create the *directory* never
helped because the watcher wants the *file*. Recorded in a comment at the watcher
site. The fix is to watch the directory instead; that is a watcher-lifetime
change and belongs with Q1, not here.
