# agent-console (Pi + Neovim + Zellij) — Design Draft v1

## Goal
Build a terminal-native "agent console" that gives a desktop-like coding-agent experience (Codex/Cursor style) while keeping your preferred stack:
- Pi for agent sessions
- Neovim for review/navigation operations
- Zellij for pane/session orchestration

This setup should prioritize:
- Diff-centric review
- Fast Git workflows (lazygit)
- Fast tree/file traversal
- Agent session management ergonomics

---

## Product Definition

### Product name
**agent-console**

### Primary user story
> As a developer, I want to run and manage one or more Pi sessions while reviewing/applying changes in Neovim, inside a reproducible Zellij workspace, so I can work like Codex desktop/Cursor agents without leaving terminal.

### Non-goals (for v1)
- Full GUI/TUI replacement for Pi internals
- Multi-machine distributed agent orchestration
- Perfect generic plugin framework for all editors

---

## UX Model

## Workspace layout (Zellij)
- **Normal mode**:
  - Pi occupies the full useful workspace.
  - Neovim is not visible by default.
  - Neovim may still be running in a hidden/fullscreen-obscured pane so review mode can appear instantly.
  - Bottom compact bar/pane (optional in v1): status + quick controls.
- **Review mode**:
  - Neovim occupies the full useful workspace.
  - The Pi pane is hidden entirely, not merely shrunk.
  - Zellij should make it visually obvious that the user is reviewing in Neovim and how to return to Pi.

## Interaction model
- Pi does analysis and proposes edits.
- Neovim is optimized for:
  - viewing diffs
  - scanning file tree
  - lazygit operations
  - quick search/jump
- Human approves/rejects through Neovim + Git.
- Agent-driven UI changes should be workflow-level and deterministic:
  - The agent may make one explicit tool call to start a review.
  - After review starts, the user controls when to leave review mode through Zellij keybindings.
  - The agent should not infer that review is complete from timing, focus changes, or silence.

## Session model
- One Zellij tab == one "agent workspace"
- Each tab can map to:
  - one Pi conversation/session
  - one Neovim instance rooted at project cwd

---

## Architecture

## IPC choice
**Neovim RPC socket** (`--listen`) for Pi -> Neovim control.

One Neovim server socket per workspace, created under a runtime temp directory, e.g.:
- `RUNTIME_DIR="$(mktemp -d /tmp/agent-console.XXXXXX)"`
- `NVIM_LISTEN_ADDRESS="$RUNTIME_DIR/nvim.sock"`

Pi extension sends commands to Neovim through RPC-compatible invocation.

## Reliability constraints
- Retry/backoff when socket is not yet ready
- Graceful handling when Neovim restarts
- Clear tool errors when socket is unavailable

---

## Feature Set

## MVP Core
1. **Output package command `agent-console`** (from this repo) launches Zellij workspace
2. **Main pane runs Pi** with new/resume behavior via Pi CLI args
3. **Hidden/non-visible Neovim pane runs Neovim** (agentic review profile) for instant review-mode activation
4. **No sidebar plugin** in MVP
5. **Pi -> Neovim integration** via Neovim RPC socket remains in scope (can be incremental after launcher/layout works)

## v1.1 Nice-to-have
- Multi-agent tabs with naming convention
- Session status bar (active model, branch, dirty state)
- Quick command palette for common workflows

## Review Mode UX

Review mode is the main agent-console workflow abstraction.

Lifecycle:

```text
normal layout: Pi full workspace, Neovim hidden
  ↓ agent calls agent_console_start_review(...)
review layout: Neovim full workspace, Pi hidden
  ↓ user presses configured Zellij return keybinding
normal layout: Pi full workspace, Pi focused
```

Important constraints:
- Entering review mode is agent-initiated with one tool call.
- Leaving review mode is user-initiated with a Zellij keybinding.
- No accept/reject hotkeys are required for now.
- No agent inference is required beyond deciding to start review.
- The agent should tell the user what was opened and which keybinding returns to Pi.

Initial keybinding candidates, subject to live conflict testing:
- return to Pi / normal layout
- focus Pi
- focus Neovim
- toggle review layout manually
- toggle Neovim tree/sidebar

Keybinding requirements:
- Must not conflict with Zellij defaults or Neovim mappings.
- Must not use `Ctrl-g` because Zellij uses it for lock mode.
- Should be configurable from the agent-console launcher/module.

---

## Neovim Profile (Agentic)

Principles:
- Review > Edit
- Diff/Git first-class
- Fast project traversal

Key capabilities:
- Diffview open/close/history
- lazygit toggles
- nvim-tree focusing + reveal current file
- Telescope for file/grep/buffers
- Minimal friction keymaps

---

## Pi Extension Responsibilities

Prefer workflow-level tools over low-level editor/layout manipulation.

Primary planned tool:
- `agent_console_start_review`
  - Opens the relevant file or diff in Neovim.
  - Switches Zellij into review mode.
  - Hides the Pi pane entirely.
  - Displays or communicates concise return instructions to the user.
  - Returns after initiating review; it does not wait for or infer review completion.

Lower-level implementation tools may still exist internally or for debugging:
- `nvim_open_file`
- `nvim_show_diff`
- `nvim_focus_tree`

The system prompt should guide the agent to use `agent_console_start_review` when the human needs to inspect code, then stop manipulating the UI until the user responds.

---

## Zellij Responsibilities

- Deterministic startup layout.
- Normal mode: Pi full workspace; Neovim hidden/non-visible.
- Review mode: Neovim full workspace; Pi pane hidden entirely.
- Export shared env vars used by both panes (including Neovim socket path).
- Optional workspace metadata (tab name, project path).
- Own the review lifecycle after the agent starts it:
  - restore normal layout
  - focus Pi
  - optionally show status/help text
- Provide conflict-audited keybindings. Do not use `Ctrl-g`, because it conflicts with Zellij lock mode.

---

## Success Criteria

1. `agent-console` command opens reproducible workspace every time.
2. From Pi, invoking review integration visibly switches to Neovim review mode.
3. Normal mode hides Neovim and makes Pi the full work surface.
4. Review mode hides the Pi pane entirely and makes Neovim the full review surface.
5. A user keybinding restores the normal layout and focuses Pi without requiring agent inference.
6. Developer can do review/apply loops primarily via diffs + lazygit.
7. Setup is declarative in this repo and easy to extend.

---

## MVP Package/Module Contract

Output in this repo:
- `flakeModules.agent-console`
- `packages.agent-console` (launcher command)

Config surface (MVP):
- `enable`
- `piPackage`
- `nvimPackage`
- `zellijPackage`
- `resumeMode` (`auto|new|resume`)
- `piArgs` (pass-through)
- `rightPaneWidth`
- `startNvimCollapsed`
- `projectRootMode` (`cwd|git-root`)

Planned review-mode config surface:
- `reviewReturnKeybinding`
- `focusPiKeybinding`
- `focusNvimKeybinding`
- `toggleReviewKeybinding`
- `toggleTreeKeybinding`
- `appendAgentConsoleSystemPrompt` or equivalent system-prompt injection

Approval workflow in MVP:
- Approve/apply through Git/lazygit

---

## Current Repo Reconciliation (High-level)

Current uncommitted code contains scaffolding but also invalid pieces.
Planned reconciliation strategy:
1. Keep only useful structural bits (zellij launcher/layout skeleton)
2. Remove/replace invalid Pi extension + invalid nixvim plugin declarations
3. Rebuild integration incrementally with testable checkpoints

(See TODO doc for concrete tasks.)
