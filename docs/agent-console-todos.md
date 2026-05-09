# agent-console TODOs

## Phase 0: Align on design
- [x] Confirm design decisions in `docs/agent-console-design.md`
- [x] Freeze v1 scope

## Phase 1: Reconcile existing uncommitted code
- [x] Audit each changed/new file for keep/remove/replace
- [x] Remove broken nixvim plugin declarations
- [x] Remove invalid Pi extension scaffold
- [x] Keep and sanitize zellij launcher/layout where useful
- [x] Ensure key package evals pass (`packages.agent-console`, `packages.zellij`)

## Phase 2: Build MVP launcher/layout
- [x] Add `flakeModules.agent-console`
- [x] Add `packages.agent-console` launcher command
- [x] Start Zellij with main Pi pane + right collapsible Neovim pane
- [x] Implement Pi new/resume startup behavior via Pi CLI args
- [x] Add config options: resumeMode, piArgs, rightPaneWidth, startNvimCollapsed, projectRootMode

## Phase 3: Agentic Neovim profile
- [x] Add/adjust diffview, lazygit, nvim-tree, telescope config
- [x] Keymaps focused on review/navigation
- [ ] Validate ergonomics in live workflow

## Phase 4: Pi -> Neovim RPC integration
- [x] Implement Neovim RPC socket runtime setup via `mktemp -d` runtime dir
- [x] Export socket env vars
- [x] Implement Pi extension tools (`nvim_open_file`, `nvim_show_diff`, `nvim_focus_tree`)
- [ ] Validate end-to-end Pi-driven Neovim actions

## Phase 4.5: Review/context orchestration
- [ ] Design `agent_console_start_review` tool schema
- [ ] Implement `agent_console_start_review` as the preferred workflow-level tool
- [ ] Start in Pi fullscreen with Neovim hidden by default
- [ ] Keep Neovim process alive for instant reveal
- [ ] Reveal Neovim and show target file/diff from a single tool call
- [ ] Ensure post-review focus to Pi keeps split mode visible (context preserved)
- [ ] Add keybindings for focus Pi, focus Neovim, toggle Pi fullscreen, and toggle Neovim tree/sidebar
- [ ] Optionally add Neovim fullscreen toggle while preserving split as the steady state
- [ ] Audit proposed keybindings against Zellij defaults and Neovim mappings
- [ ] Ensure `Ctrl-g` is not used because it conflicts with Zellij lock mode
- [ ] Make keybindings configurable
- [ ] Add agent-console system prompt guidance for deterministic review/context usage
- [ ] Ensure the agent does not need to infer review completion after starting review

## Phase 5: Stability and docs
- [x] Add error handling/timeouts in RPC calls
- [x] Handle restart/disconnect cases gracefully
- [x] Document usage (`agent-console`, keymaps, expected workflow)
- [x] Add troubleshooting section

## Stretch
- [ ] Left sidebar sessions plugin
- [ ] Multi-tab multi-agent/session orchestration (one workspace per tab)
- [ ] Status pane with session metadata
