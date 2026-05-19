# pi-prelude: Design, Constraints, and Incremental Spec Workflow

## 1) Goal

`pi-prelude` is a **Nix-first Pi module/profile** in this repo (under `pi/prelude/`) that provides a practical default Pi runtime:

- hotkey-first working modes (plan/build/debug/review/quick)
- a small set of high-leverage tools (ask user, todo, web search/fetch)
- safety guardrails
- aesthetic + functional status UX
- minimal prompts and skills

`pi install` support is secondary.

---

## 2) Scope and Non-Goals

### In scope (MVP)

- Folder: `pi/prelude/`
- Export as `flakeModules.pi-prelude`
- Package output: `packages.pi-prelude`
- Extensions:
  - `mode.ts`
  - `tools-ask.ts`
  - `tools-todo.ts`
  - `tools-web.ts`
  - `guardrails.ts`
  - `status.ts`
- Prompt templates/skills are optional and should be added only for repeated high-value workflows
- Configurable via module options + project/user mode config files

### Out of scope (MVP)

- Crawl4AI backend integration
- Browser automation stack
- heavy background crawling/indexing
- auto-commit and advanced git automation
- complex custom TUI frameworks

---

## 3) Constraints

1. **Nix-native first**
   - Must work as flake module in this repo.
   - Must not require `pi install`.
2. **Module layout aligned with repo conventions**
   - Module lives under `pi/prelude/` (with Pi-owned code under `pi/`).
3. **Hotkey-first UX**
   - Mode switching should be immediate during active prompting workflow.
4. **Low operational complexity**
   - Prefer lightweight web/search tooling in MVP.
5. **Safety defaults**
   - Guardrails on dangerous file writes and shell commands.
6. **Incremental, testable changes**
   - Each extension delivered in small vertical slices.
7. **Composable with existing repo modules**
   - Must not break `pi`, `agent-console`, or devShell ergonomics.
8. **Extension fault isolation**
   - Extension runtime failures must degrade gracefully (fallback behavior + notification), and must not block opening/using Pi.

---

## 4) Architecture

## 4.1 Module and package

- `pi/prelude/module.nix` defines:
  - `devtools.pi.prelude.enable`
  - `devtools.pi.prelude.package` (base Pi package)
  - `devtools.pi.prelude.extraExtensionSources`
  - `devtools.pi.prelude.extraArgs`
- Produces:
  - `packages.pi-prelude-package` (derivation containing only `pi/prelude/`)
  - `packages.pi-prelude` via `pi/default.nix` wrapper.

## 4.2 Runtime assets

- Prelude resources are loaded from a single package source path via wrapper `--extension <pi-prelude-package>`
- Extra sources can be appended via `devtools.pi.prelude.extraExtensionSources`
- Optional secondary packaging in `pi/prelude/package.json`

## 4.3 Configuration discovery and layering

For extension configs, use Pi-aware discovery:
1. project override: nearest-upward `.pi/prelude/<name>.json` from `ctx.cwd`
2. user override: `${getAgentDir()}/prelude/<name>.json`
3. extension defaults

Guardrails path config uses gitignore-like pattern lists (`*Patterns`) and `/`-anchored rules resolve from git root.

Stable config file names for MVP:
- modes: `.pi/prelude/modes.json` and `${getAgentDir()}/prelude/modes.json`
- guardrails: `.pi/prelude/guardrails.json` and `${getAgentDir()}/prelude/guardrails.json`

Guidelines:
- Use `getAgentDir()` from `@mariozechner/pi-coding-agent` for user-level config.
- Do not hardcode `~/.pi/agent` or rely on `$HOME` directly.
- Parent traversal from `ctx.cwd` avoids assuming cwd is project root.
- Optionally stop at git root for project scoping.

---

## 5) Functional Spec (MVP)

## 5.1 `mode.ts` (hotkey-first preset system)

### Required behavior
- Define modes: `plan`, `build`, `debug`, `review`, `quick`
- Each mode can set:
  - tools allowlist
  - thinking level
  - optional model/provider
  - appended instructions
- Persist active mode in session custom entry.
- Show active mode in status.

### Required controls
- `Ctrl+Shift+U`: cycle modes
- direct toggles (exact keys configurable):
  - plan/build toggle
  - review
  - debug
- `/mode` and `/mode <name>` command (secondary UX)

### Plan mode semantics
- read-only tooling by default
- strong planning instruction append
- asks clarifying questions when ambiguous

## 5.2 `tools-ask.ts`

### Tool
- `ask_user`

### Required behavior
- single-question flow
- multi-question flow
- option selection + optional freeform response
- returns structured answers in `details`
- works only in interactive mode; clear error otherwise

## 5.3 `tools-todo.ts`

### Tool
- `todo`

### Actions
- `list`, `add`, `update`, `done`, `clear`

### Required behavior
- branch-aware state reconstruction from tool result details
- optional `/todos` read UI
- no external DB/files for state

## 5.4 `tools-web.ts`

### Tools
- `web_search`
- `web_fetch`

### Required behavior
- lightweight backend first (CLI/http)
- bounded output/truncation
- URL citation in results
- deterministic error messages

### Deferred
- optional deep fetch backend (Crawl4AI) as pluggable v2

## 5.5 `guardrails.ts`

### Required behavior
- block or confirm operations using gitignore-like pattern lists
- read-protect secrets by default (`/.env`, private keys/credential files), while allowing `/.env.example` and `/.envrc`
- write-protect by default (`/.env`, `/.git/**`, `**/node_modules/**`, build dirs)
- confirm dangerous bash commands:
  - `rm -rf`, `sudo`, hard resets/clean, deploy/publish class commands
- clear user-facing reason when blocked

## 5.6 `status.ts`

### Required behavior
- always show mode
- show model/thinking
- show git branch + dirty marker
- show coarse context usage when available
- show working indicator while agent is active

### UX principles
- muted by default, high contrast only for warnings
- stable layout (low flicker)
- compact fallback for narrow terminal widths

---

## 6) Design notes: Crawl4AI

Crawl4AI is a good **v2 deep-fetch** candidate, not MVP.

- Pros: better extraction quality, dynamic pages, richer crawl workflows
- Cons: heavier runtime/deps, more failure surfaces, slower iteration

Decision:
- MVP = lightweight `web_search` + `web_fetch`
- Later add optional `web_fetch_deep` backend with feature flag

---

## 7) Minimal Spec-Driven Development Workflow

Use short cycles per feature with acceptance checks.

## 7.1 Artifacts per feature

For each extension feature `X`, create:
1. `docs/pi/prelude/specs/X.md`
   - problem
   - API/schema
   - events/hooks used
   - failure modes
   - acceptance criteria
2. implementation file in `pi/prelude/extensions/`
3. minimal test script in `tests/` (behavioral where possible)
4. changelog note in PR description

## 7.2 Delivery phases

### Phase 0 (done)
- scaffold module + placeholders

### Phase 1
- implement `mode.ts` core + hotkeys + `/mode`
- implement `status.ts` minimal mode/model display

### Phase 2
- implement `tools-ask.ts`
- implement `tools-todo.ts`

### Phase 3
- implement `guardrails.ts`
- implement `tools-web.ts` lightweight backend

### Phase 4
- evaluate whether prompts/skills are justified by repeated workflows (optional)
- tighten docs and tests

## 7.3 Acceptance gate per phase

A phase is done when:
- behavior matches its spec doc acceptance criteria
- no regressions in existing checks
- module still builds and `packages.pi-prelude` runs
- interactive smoke test is documented

---

## 8) Testing Strategy (pragmatic)

- **Static checks**: `nix flake check`
- **Build checks**: ensure wrapper package builds on configured systems
- **Behavior checks**:
  - shell-script tests for wrapper flags and file wiring
  - extension-level smoke scenarios (manual transcript until RPC harness exists)
- **Manual smoke list** for each release:
  - switch modes via hotkey while composing prompt
  - run ask/todo/web tools
  - verify guardrails block/confirm behavior
  - verify status updates in idle/working states

---

## 9) Decisions status

Resolved:
1. Module placement: under `pi/prelude/` (not top-level)
2. Module filename convention: `module.nix` (aligned with other folders)

Still open:
1. Web backend order/fallbacks and required runtime deps in Nix
2. Protected path defaults and project overrides

---

## 10) Follow-up alignment

Config discovery alignment has been applied:
- mode config via `getAgentDir()/prelude/modes.json` and nearest-upward `.pi/prelude/modes.json`
- guardrails config via `getAgentDir()/prelude/guardrails.json` and nearest-upward `.pi/prelude/guardrails.json`.
