# Spec: `mode.ts` (Phase 1)

## Goal

Provide a hotkey-first mode system for Pi so users can switch behavior instantly (especially while composing prompts), with command support as fallback.

## Scope

In scope:
- Modes: `plan`, `build`, `debug`, `review`, `quick`
- Hotkey controls + `/mode` command
- Apply per-mode tools/thinking/model/instructions
- Persist active mode in session state
- Expose active mode for status extension

Out of scope:
- Fancy selector UI
- Per-project permission policies (handled by guardrails)
- Deep model/provider orchestration beyond simple optional override

## Config Model

Mode schema (conceptual):

```json
{
  "plan": {
    "provider": "anthropic",
    "model": "claude-sonnet-4-5",
    "thinkingLevel": "high",
    "tools": ["read", "grep", "find", "ls", "ask_user", "todo", "web_search", "web_fetch"],
    "instructions": "Planning mode instructions..."
  }
}
```

Fields per mode:
- `provider?`: string
- `model?`: string
- `thinkingLevel?`: `off|minimal|low|medium|high|xhigh`
- `tools?`: string[]
- `instructions?`: string

## Config Resolution

Precedence (highest first):
1. project: `.pi/prelude/modes.json`
2. user: `${getAgentDir()}/prelude/modes.json`
3. built-in defaults in extension

Unknown mode fields are ignored with warning.

## UX Contract

### Hotkeys (default, conflict-aware)
- `Ctrl+Alt+U`: cycle modes
- `Ctrl+Alt+P`: toggle `plan <-> build`
- `Ctrl+Alt+R`: switch `review`
- `Ctrl+Alt+D`: switch `debug`

Rationale:
- Avoids common WezTerm defaults like `Ctrl+Shift+P` (command palette).
- Avoids common tab/session shortcuts (`Ctrl+Shift+T/W/F/L`).
- Does not depend on Zellij leader bindings (typical Zellij flow uses `Ctrl+G` prefix).

### Commands
- `/mode` → show/select current mode (simple list/select or notify with choices)
- `/mode <name>` → apply directly

### Hotkey override
Hotkeys must be configurable via extension config so users can remap around terminal-specific collisions.

### Persistence
- Write custom entry: `mode-state` with `{ name: <mode> }`
- On `session_start`, restore mode name and apply config if available

## Runtime Behavior

When applying mode:
1. Snapshot original state once (model, thinking level, active tools)
2. Resolve mode config
3. Optionally set model (if provider+model set and available)
4. Set thinking level (if provided)
5. Set active tools (validate against available tool names)
6. Mark active mode in extension state
7. Inject mode instructions in `before_agent_start` (if provided)
8. Update status key: `mode:<name>`

Clearing mode:
- Optional `none` mode can restore original state snapshot.

## Failure Modes

- Unknown mode name → notify error + no changes
- Unknown tools in mode config → warn and ignore invalid tools
- Missing API key/model not found → warn, continue applying other mode parts
- Bad JSON in config file → warn, continue with lower precedence/defaults

## Acceptance Criteria

1. User can switch to each mode via `/mode <name>`.
2. `Ctrl+Alt+U` (or configured equivalent) cycles modes deterministically.
3. Switching modes updates tools and thinking level as configured.
4. Mode instructions are appended to system prompt for subsequent turns.
5. Active mode survives session continuation via `mode-state`.
6. Invalid config/tool/model produces warning without crashing.
7. Status extension can read/display active mode signal.

## Test Plan (minimal)

Manual smoke:
1. Start Pi with `packages.pi-prelude`.
2. Run `/mode plan` → verify read-only tool profile.
3. Press `Ctrl+Alt+P` → verify plan/build toggle.
4. Press `Ctrl+Alt+U` repeatedly → verify cycle order stability.
5. Continue session, restart with `-c` → verify mode restored.
6. Add invalid tool in `.pi/prelude/modes.json` → verify warning and partial apply.

Future automated checks:
- extension unit-ish behavior via mocked mode resolution/apply helpers
- script-level assertions for wrapper wiring
