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
- Left pane: **Pi session** (main chat / tool execution)
- Right pane: **Neovim review workspace**
- Bottom compact bar/pane (optional in v1): status + quick controls

## Interaction model
- Pi does analysis and proposes edits
- Neovim is optimized for:
  - viewing diffs
  - scanning file tree
  - lazygit operations
  - quick search/jump
- Human approves/rejects through Neovim + Git

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
3. **Right collapsible pane runs Neovim** (agentic review profile)
4. **No sidebar plugin** in MVP
5. **Pi -> Neovim integration** via Neovim RPC socket remains in scope (can be incremental after launcher/layout works)

## v1.1 Nice-to-have
- Multi-agent tabs with naming convention
- Session status bar (active model, branch, dirty state)
- Quick command palette for common workflows

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

- Expose explicit tools for Neovim orchestration:
  - `nvim_open_file`
  - `nvim_show_diff`
  - `nvim_focus_tree`
- Call Neovim through RPC socket-targeted commands
- Validate responses and return structured errors

---

## Zellij Responsibilities

- Deterministic startup layout
- Main Pi pane + right collapsible Neovim pane
- Export shared env vars used by both panes (including Neovim socket path)
- Optional workspace metadata (tab name, project path)

---

## Success Criteria

1. `agent-console` command opens reproducible workspace every time.
2. From Pi, invoking integration tools visibly drives Neovim actions.
3. Developer can do review/apply loops primarily via diffs + lazygit.
4. Setup is declarative in this repo and easy to extend.

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
