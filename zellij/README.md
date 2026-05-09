# zellij module scaffold

This folder defines the repo's generic zellij output:
- `zellij/default.nix` → `packages.zellij` (wrapper around zellij with repo config)
- `zellij/module.nix` registers that package in the flake
- `zellij/config.kdl` shared zellij config

Scope note: agent-console-specific layouts/launch behavior live in `agent-console/`.
