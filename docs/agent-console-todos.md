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

## Phase 5: Stability and docs
- [ ] Add error handling/timeouts in RPC calls
- [ ] Handle restart/disconnect cases gracefully
- [ ] Document usage (`agent-console`, keymaps, expected workflow)
- [ ] Add troubleshooting section

## Stretch
- [ ] Left sidebar sessions plugin
- [ ] Multi-tab multi-agent session orchestration
- [ ] Status pane with session metadata
