# zellij module scaffold

This folder defines the repo's zellij output:
- `zellij/default.nix` → `packages.zellij` (wrapper around zellij with repo config)
- `zellij/module.nix` registers that package in the flake
- `zellij/config.kdl` shared zellij config
- `zellij/layouts/agent-console.kdl` reference layout

`agent-console` builds on top of this zellij package and the neovim package.
