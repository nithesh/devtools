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
- **Default working mode (startup)**:
  - Pi occupies the full useful workspace.
  - Neovim is not visible by default.
- **Split working mode (after review starts)**:
  - Pi remains visible on the left.
  - Neovim is visible on the right and keeps the current file/diff context.
  - This is the primary "work while seeing context" mode.
- **Optional focused review mode**:
  - Neovim can be temporarily fullscreen when desired.
  - Returning focus to Pi should restore split mode (not hide Neovim again).
- Bottom compact bar/pane (optional in v1): status + quick controls.

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
- One Zellij tab == one "agent workspace" (future multi-session/project scaling model).
- Within a workspace tab, use persistent panes (Pi + Neovim) rather than switching tabs for review.
- Each workspace tab can map to:
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

## Review/Context UX

Context visibility is the main agent-console workflow abstraction.

Lifecycle:

```text
default working mode: Pi fullscreen, Neovim hidden
  ↓ agent calls agent_console_start_review(...)
split working mode: Pi left + Neovim right (file/diff shown)
  ↓ user focuses Pi to continue chatting
split working mode persists (Neovim remains visible)
  ↓ optional user action
Pi fullscreen again (hide Neovim)
```

Important constraints:
- Transition from default mode to split mode is agent-initiated with one tool call.
- After that, no further agent inference is needed.
- No accept/reject hotkeys are required for now.
- Focus changes should not destroy visible Neovim context.
- The agent should tell the user what was opened and how to return focus to Pi.

Initial keybinding candidates, subject to live conflict testing:
- focus Pi
- focus Neovim
- toggle Pi fullscreen (hide/show Neovim)
- optional Neovim fullscreen toggle
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
  - Switches from default mode (Pi fullscreen) to split mode (Pi + Neovim visible).
  - Focuses Neovim initially for review, while preserving easy return to Pi.
  - Displays or communicates concise focus/layout instructions to the user.
  - Returns after initiating review; it does not wait for or infer review completion.

Lower-level implementation tools may still exist internally or for debugging:
- `nvim_open_file`
- `nvim_show_diff`
- `nvim_focus_tree`

The system prompt should guide the agent to use `agent_console_start_review` when the human needs to inspect code, then stop manipulating the UI until the user responds.

---

## Zellij Responsibilities

- Deterministic startup layout.
- Default mode: Pi full workspace; Neovim hidden/non-visible.
- Split mode: Pi + Neovim both visible, with Neovim preserving review context.
- Optional focused Neovim mode: temporary Neovim fullscreen.
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
2. Startup is Pi fullscreen by default.
3. From Pi, invoking review integration reveals Neovim and shows the requested file/diff.
4. Returning focus to Pi keeps Neovim visible in split mode (context preserved).
5. A user keybinding can toggle Pi fullscreen to hide/show Neovim deterministically.
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

Planned review/context config surface:
- `focusPiKeybinding`
- `focusNvimKeybinding`
- `togglePiFullscreenKeybinding` (hide/show Neovim deterministically)
- `toggleNvimFullscreenKeybinding` (optional)
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
