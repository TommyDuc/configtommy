# CoC → Native LSP Migration Plan

Migration of the Neovim configuration in this repo off `neoclide/coc.nvim` and onto
Neovim's native LSP client.

Target Neovim: **v0.12.5** (verified locally). Several steps below depend on APIs that
only exist in 0.11/0.12 and were confirmed present on this machine:

```
vim.lsp.buf.selection_range   ✅   vim.lsp.on_type_formatting   ✅
vim.lsp.completion            ✅   vim.lsp.foldexpr             ✅
vim.lsp.inlay_hint            ✅   vim.diagnostic.is_enabled    ✅
vim.lsp.buf.incoming_calls    ✅   vim.pack                     ✅
```

---

## 0. Audit findings (state of the config before migration)

These were established by inspecting the repo and `~/.config/coc/` and drive several
decisions below. Read this section before executing anything.

### 0.1 The installed extension set is not what `coc-settings.json` implies

Actually installed (`~/.config/coc/extensions/package.json`, **untracked, outside the repo**):

```
coc-bitbake  coc-csharp  coc-go     coc-html   coc-json
coc-markdownlint  coc-prettier  coc-protobuf  coc-pyright
coc-rust-analyzer  coc-sh  coc-toml  coc-tsserver  @yaegassy/coc-ruff
```

### 0.2 Dead configuration (delete, do not port)

Not installed, yet configured — these settings have had **no effect**:

| Dead config | Location | Reason |
| --- | --- | --- |
| all `cSpell.*` / `cSpellExt.*` (~40 lines, incl. the 30-entry `enabledLanguageIds`) | `coc-settings.json` | `coc-spell-checker` not installed |
| `nix.enableLanguageServer`, `nix.serverPath: nixd` | `coc-settings.json` | `coc-nix` not installed |
| `[lua]` `formatOnSave` / `formatOnType` | `coc-settings.json` | no Lua server installed |
| `<C-j>` → `<Plug>(coc-snippets-expand-jump)` | `coc.lua:50` | `coc-snippets` not installed |

### 0.3 Other latent issues found

- **`nvim/lua/after/plugin/snacks.lua` is dead code.** It contains a lazy.nvim plugin
  spec as a *bare table* (no `return`), lives in `after/plugin/` instead of
  `lua/plugins/`, is absent from `after/plugin/init.lua`, and has 0 entries in
  `lazy-lock.json`. `snacks.nvim` is **not installed**. It also sets
  `input = { enabled = false }` — the exact module Phase 4 wants.
- **All `.json` files are filetype `jsonc`.** `nvim/lua/tommy/editor.lua:20` does
  `vim.filetype.add({extension = {json="jsonc"}})`. Consequently the autocmd
  `FileType typescript,json → formatexpr` (`coc.lua:265-270`) has been **silently never
  firing for JSON**. Every new config must target `jsonc`, not `json`.
- **`vim.opt.signcolumn = "yes"` is set twice** — `editor.lua:15` and `coc.lua:13`.
- **No `nvim-treesitter` is installed.** Relevant to Phase 4 textobjects.

### 0.4 Server availability

Servers are provisioned **per-project via nix flakes, or system-wide** — not by the
Neovim config. Therefore: resolve every binary **via `PATH`**, never an absolute path,
and do **not** add `mason.nvim`. This matches the existing intent in `coc-settings.json`
(`"go.goplsPath": "gopls"` — *"Resolve via PATH; useful for nix flakes"*).

Current state on `PATH`:

| Binary | Status |
| --- | --- |
| `gopls`, `pyright`, `ruff`, `rust-analyzer` | present |
| `typescript-language-server`, `bash-language-server`, `vscode-json-languageserver`, `buf` | **missing** |
| `prettier`, `markdownlint-cli2` | **missing** |

> **Consequence:** this migration removes the **CoC RPC layer**, not Node.
> `ts_ls`, `bashls`, `jsonls`, `prettier` and `markdownlint-cli2` are Node programs
> regardless of client.

### 0.5 Agreed scope cuts

**Dropped, not ported:** `coc-bitbake`, `coc-csharp`, `coc-html`, `coc-toml`
(→ no bitbake, csharp, html, or taplo server).

**8 servers to port:** `gopls`, `pyright`, `ruff`, `ts_ls`, `rust_analyzer`, `bashls`,
`jsonls`, `bufls`.

---

## Phase 0 — Preparation

1. **Record the extension inventory into the repo** before deleting anything. The list
   in §0.1 is the only existing record and lives in untracked state outside the repo.
2. **Write a server/tool manifest** into `AGENTS.md`: the 8 servers plus `prettier` and
   `markdownlint-cli2`, with the expected provisioning route (per-project flake vs.
   system-wide). This replaces coc-extensions as the source of truth for "what needs to
   be installed".

**Exit criteria:** inventory committed; manifest drafted.

---

## Phase 1 — Native LSP core

### Files

```
nvim/lsp/gopls.lua
nvim/lsp/pyright.lua
nvim/lsp/ruff.lua
nvim/lsp/ts_ls.lua
nvim/lsp/rust_analyzer.lua
nvim/lsp/bashls.lua
nvim/lsp/jsonls.lua
nvim/lsp/bufls.lua
nvim/lua/after/plugin/lsp.lua      -- keymaps, diagnostics, autocmds, commands
```

`install.sh` symlinks `nvim/` → `~/.config/nvim`, so `nvim/lsp/` is on the runtimepath
and is auto-discovered by Neovim 0.11+. Each file returns a table
(`cmd`, `filetypes`, `root_markers`, `settings`). **Do not add `nvim-lspconfig`** — it is
unnecessary on 0.12 for this server set.

### 1.1 Executable guard

Servers appear and disappear depending on which nix flake shell nvim was launched from.
`vim.lsp.enable` on a non-executable `cmd` produces error spam.

Add a helper in `after/plugin/lsp.lua` that filters the enable list through
`vim.fn.executable()` at startup, so a missing server is silently skipped.

> **Documented limitation:** nvim launched outside a project's flake shell will not see
> that flake's servers. This is identical to the current behaviour under CoC.

### 1.2 Settings to carry over from `coc-settings.json`

| CoC setting | Destination |
| --- | --- |
| `python.analysis.diagnosticMode: "workspace"` | `pyright.settings` |
| `pyright.organizeimports.provider: "ruff"` | `pyright.settings` |
| `pyright.testing.provider: "pytest"` | `pyright.settings` |
| `python.venvPath: "${cwd}"` | resolve in a config function in `pyright.lua` |
| `go.goplsPath: "gopls"` | `cmd = {"gopls"}` (PATH resolution is the default) |
| `languageserver.bufls` block | `nvim/lsp/bufls.lua`, near-verbatim |
| `python.linting.ruffEnabled` | `ruff.lua` (separate server) |

**`jsonls.filetypes` must be `{"json", "jsonc"}`** — mandatory, see §0.3.

### 1.3 Diagnostics → `vim.diagnostic.config`

| CoC | Native |
| --- | --- |
| `diagnostic.enable: true` | default |
| `diagnostic.refreshOnInsertMode: false` | `update_in_insert = false` |
| `diagnostic.virtualText: true` | `virtual_text = {...}` |
| `diagnostic.virtualTextCurrentLineOnly: false` | default |
| `diagnostic.virtualTextLimitInOneLine: 1` | `virtual_text` opts |
| `diagnostic.virtualTextAlign: "below"` + `virtualTextLines: 2` | **`virtual_lines`**, not `virtual_text` |
| `diagnostic.enableMessage: "jump"` | `jump = { on_jump = <open_float> }` |

### 1.4 Keymaps to port

| Key | Source | Native |
| --- | --- | --- |
| `gd` / `gy` / `gi` / `gr` | `coc.lua:60-63` | `vim.lsp.buf.definition` / `type_definition` / `implementation` / `references` |
| `[g` / `]g` | `56-57` | `vim.diagnostic.jump{count = ∓1}` |
| `<leader>a` (n,x) | `275-276` | `code_action` over range/motion |
| `<leader>ac` | `279` | `code_action` at cursor |
| `<leader>as` | `281` | `code_action{ context.only = {"source"} }` |
| `<leader>al` | `283` | `code_action{ context.only = {"quickfix"}, apply = true }` |
| `<leader>re` / `<leader>r` | `286-288` | `code_action{ context.only = {"refactor"} }` |
| `<leader>cl` | `291` | `vim.lsp.codelens.run()` + refresh autocmd |
| `<leader>hi` | `361-362` | `vim.lsp.inlay_hint.enable(not is_enabled())` |
| `<leader>ho` / `<leader>hc` | `364-368` | `vim.lsp.buf.outgoing_calls` / `incoming_calls` |
| `<C-s>` (n,x) | `321-322` | `vim.lsp.buf.selection_range()` |

**`K` needs no mapping** — `vim.lsp.buf.hover` has been the default since 0.10.

Retain `updatetime = 200` (`coc.lua:9`).

### 1.5 Deletions in this phase

| Delete | Reason |
| --- | --- |
| `_G.show_docs` (`coc.lua:67-77`) | the vim/help + `keywordprg` fallback is builtin |
| `vim.opt.signcolumn` (`13`) | duplicate of `editor.lua:15` |
| `<C-f>` / `<C-b>` float scroll (`309-316`) | native floats: press `K` twice to enter and scroll |
| `check_back_space` | keep — still needed in Phase 2 |

### 1.6 `gK` / `yank_type` (`coc.lua:80-194`)

The most valuable custom code in the config, and **almost fully portable**.

- `hover_code_block`, `top_level_colon`, `trim`, `extract_type` port **verbatim** — pure
  Lua with no CoC dependency.
- Only the request changes: `CocActionAsync("getHover", cb)` →
  `vim.lsp.buf_request(0, "textDocument/hover", params, cb)`.
- **Handle both response shapes**: modern `result.contents` as `MarkupContent`
  (`{kind, value}`) and the legacy array/`MarkedString` form. The existing `chunks` loop
  already splits multi-line chunks correctly.
- Preserve current behaviour: capture `vim.v.register` before the async call; mirror into
  `"0` when the register is `"`; `vim.notify` on failure rather than yanking something wrong.

### 1.7 Diagnostic toggles (`coc.lua:371-421`) — ~50 lines → ~12

The current implementation mirrors state because *"coc exposes no way to query whether
diagnostics are currently enabled"*. Native does: `vim.diagnostic.is_enabled()`.

- **Delete:** `diag_global_on`, `diag_buffer_on`, the `BufDelete` cleanup autocmd, and
  the "state can drift" caveat.
- **Keep:** `DIAG_OFF_MARKER`, `DIAG_GLOBAL_MARKER`, and the statusline function (rename
  `_G.coc_diag_status`), including the global-marker-wins-over-buffer-marker rule.
- `<leader>ha` → `vim.diagnostic.enable(not vim.diagnostic.is_enabled())`.
- `<leader>hq` → same with `{ bufnr = 0 }`.

### 1.8 Autocmds & commands

- **Document highlight** — replaces `CursorHold → CocActionAsync('highlight')`
  (`coc.lua:199-203`). Use `LspAttach` + `CursorHold` → `vim.lsp.buf.document_highlight`,
  `CursorMoved` → `vim.lsp.buf.clear_references`.
  *Decide whether `mini.cursorword` (`mini.lua:17`) stays alongside — they overlap.*
- `:Format` → `vim.lsp.buf.format()`
- `:Fold` → `vim.lsp.foldexpr`
- `:OR` → `code_action{ context.only = {"source.organizeImports"}, apply = true }`

### 1.9 Verification

Open a Go, Python, TypeScript and Rust file. Confirm: `gd`, `gr`, `K`, `gK`,
`<leader>ac`, diagnostics rendering (incl. `virtual_lines`), inlay hint toggle,
`<leader>ha`/`<leader>hq` and their statusline markers.

---

## Phase 2 — Completion (deliberately reversible)

The philosophy to preserve, per `coc-settings.json`:

> `"suggest.autoTrigger": "none"` — *"This setting is what made me use neovim. Praise be
> the anti-popup Omnissiah!"*

### 2A — Native first (do this, then live on it 1–2 weeks)

- `vim.lsp.completion.enable{ autotrigger = false }` on `LspAttach` — an exact match for
  `autoTrigger: "none"`.
- `completeopt = "menuone,noselect,fuzzy,popup"`.
- `<C-space>` → `vim.lsp.completion.get()` (replaces `coc#refresh()`, `coc.lua:52`).
- `<TAB>` / `<S-TAB>` (`28-29`) → `pumvisible()`-guarded `<C-n>` / `<C-p>`, keeping the
  existing `check_back_space` helper.
- `<CR>` (`47`) → `pumvisible() ? "<C-y>" : "<CR>"`. Native `vim.lsp.completion` expands
  snippet-type completion items itself.
- **The `,` gopls trailing-comma hack (`33-43`) copies over unchanged** — pure Lua,
  no CoC dependency.
- `suggest.floatConfig` / `suggest.pumFloatConfig` borders → `vim.o.winborder`.
- **Delete the dead `<C-j>` snippet mapping** (`50`, see §0.2).

**Accepted losses, to be evaluated during the trial period:**

| Lost | CoC setting |
| --- | --- |
| inline ghost-text preview | `suggest.virtualText` |
| frecency ordering | `suggest.selection: "recentlyUsed"` |
| locality ranking | `suggest.localityBonus` |
| duplicate filtering | `suggest.removeDuplicateItems` |
| custom single-char kind labels | `suggest.completionItemKindLabels` |

### 2B — Fallback, only if 2A disappoints

Add `blink.cmp` with `trigger.completion.show_on_keyword = false` (preserves
manual-trigger-only), `ghost_text`, frecency sorting, and a `kind_icons` table
reproducing the single-char label map. Self-contained: Phase 1 is unaffected either way.

---

## Phase 3 — Formatting & linting

Replaces `coc.preferences.formatOnSave` / `formatOnType`, `coc-prettier`, `coc-markdownlint`.

- **`conform.nvim`** — `format_on_save` for `python` (ruff), `proto` (buf),
  `typescript` (prettier). Directly replaces the `[python]` / `[typescript]` / `[proto]`
  blocks and `coc-prettier`.
  **No `[lua]` entry** — no Lua server is installed (§0.2).
- **`formatOnType`** (`[python]`, and the dead `[lua]`) →
  `vim.lsp.on_type_formatting.enable()`. Native in 0.12, no plugin.
- **`nvim-lint` + `markdownlint-cli2`** — move `markdownlint.config`
  (`{ default: true, MD013: false }`) into a `.markdownlint.jsonc`.
- **Delete** the `FileType typescript,json → formatexpr=CocAction('formatSelected')`
  autocmd (`coc.lua:265-270`): conform sets `formatexpr` itself, and this never fired for
  JSON anyway (§0.3).
- **`json.schemaDownload.enable`** → `jsonls` + `SchemaStore.nvim`.

---

## Phase 4 — Remaining gaps

### 4.1 Treesitter textobjects

Add `nvim-treesitter` **and** `nvim-treesitter-textobjects` to restore `if`/`af`/`ic`/`ac`
(`coc.lua:296-303`). Includes a parser install step. Nothing else in this plan depends on
treesitter. Arguably an upgrade: works without an attached LSP and without
`textDocument/documentSymbol` support.

### 4.2 Fix `snacks.nvim` first

Before using it: move `nvim/lua/after/plugin/snacks.lua` → `nvim/lua/plugins/snacks.lua`,
add the missing `return`, and set `input = { enabled = true }` (§0.3).

### 4.3 `<leader>rn` — rename prompt in normal mode (**used often, must keep**)

Current implementation (`coc.lua:206-252`, 47 lines) reverse-engineers coc internals:
`pending_rename` flag, a 2s safety timer, the `User CocOpenFloatPrompt` autocmd,
`coc#dialog#get_prompt_win()`, a normal-mode `<CR>` → `coc#dialog#prompt_insert()`, and a
one-shot `InsertEnter` autocmd to undo coc's queued `feedkeys('A', 'int')`.

Replace with `snacks.input` (or a custom `vim.ui.input` float) configured to open in
**normal mode with the cursor at column 0**, feeding `vim.lsp.buf.rename`. ~30 lines of
code you own, instead of 47 lines fighting another plugin's internals.

### 4.4 `<leader>rf` — LSP-aware file rename

`:CocCommand workspace.renameCurrentFile` (`coc.lua:255`) has **no native equivalent**
(it drives `willRenameFiles`/`didRenameFiles` so imports get updated).

Use `snacks.rename`. **Bonus:** this also allows deleting the `BufFilePost` tabline-redraw
workaround in `mini.lua:33-42`, which exists only because of coc's rename path.

### 4.5 Statusline

`%{coc#status()}%{get(b:,'coc_current_function','')}` (`coc.lua:337`) →
`fidget.nvim` for `$/progress`. Drop `b:coc_current_function`.
Keep the diagnostic-marker segment from §1.7.

### 4.6 CocList → Telescope

Telescope is already a dependency.

| Old | New |
| --- | --- |
| `<leader>ca` diagnostics | `Telescope diagnostics` |
| `<leader>co` outline | `Telescope lsp_document_symbols` |
| `<leader>cs` symbols | `Telescope lsp_dynamic_workspace_symbols` |
| `<leader>cp` resume | `Telescope resume` |
| `<leader>ce` extensions | **drop** — meaningless without coc |
| `<leader>cj` / `<leader>ck` | **drop** |

### 4.7 Keymap collision check (already performed)

Taken elsewhere in the config: `<leader>s` (`remap.lua`, insert-N-chars), `s`
(`mini.lua:130`, `<Nop>`), `<leader>p*` (`remap.lua`), `<leader>m*` (mini.map),
`<leader>b*` (mini.bufremove), `<leader>g*` (gitlinker), `<leader>f*` (fff),
`<leader>n*`/`<leader>N*` (mini.diff).
**Nothing in this plan collides.** `<leader>c*` frees up.

Note `timeoutlen = 4000` (`editor.lua:17`) — unusually long, but not blocking.

---

## Phase 5 — Removal & cleanup

1. Delete `nvim/lua/plugins/coc.lua`.
2. Delete `nvim/coc-settings.json`.
3. Delete `nvim/lua/after/plugin/coc.lua`.
4. Edit `nvim/lua/after/plugin/init.lua`: remove `require("after.plugin.coc")` (line 6),
   add the new requires.
5. `:Lazy sync` to regenerate `lazy-lock.json` (drops the `coc.nvim` pin).
6. Remove the coc comment and, if 4.4 landed, the `BufFilePost` autocmd in
   `mini.lua:33-42`.
7. `rm -rf ~/.config/coc` — untracked, outside the repo.
8. Commit the server/tool manifest from Phase 0 into `AGENTS.md`.

---

## Net accounting

**Deleted**
- ~430 lines `nvim/lua/after/plugin/coc.lua`
- 169 lines `nvim/coc-settings.json` (~90 of which are dead after the §0.5 cuts)
- one Node RPC daemon
- one untracked, unversioned extension store
- two reverse-engineering workarounds (rename prompt; tabline redraw)

**Added**
- 8 small `nvim/lsp/*.lua` files
- ~180 lines `nvim/lua/after/plugin/lsp.lua`
- ~40 lines completion config
- ~30 lines rename prompt

**New plugins**
`conform.nvim`, `nvim-lint`, `SchemaStore.nvim`, `snacks.nvim` (rename + input),
`fidget.nvim`, `nvim-treesitter`, `nvim-treesitter-textobjects`
— plus `blink.cmp` only if Phase 2B is triggered.

**Genuinely lost**
- inline ghost text and frecency completion ordering (pending the 2A verdict)
- automatic language-server installation (now owned via nix flakes / system-wide)

---

## Execution order

Commit **one phase per commit**, in order. Phase 1 must land and be validated before
Phase 2 changes completion behaviour underfoot. Phase 5 must be last.

```
Phase 0  →  Phase 1  →  [validate]  →  Phase 2A  →  [1-2 week trial]
         →  Phase 3  →  Phase 4  →  Phase 5  →  [Phase 2B, only if needed]
```
