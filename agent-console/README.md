# agent-console

`agent-console` owns all cross-tool integration (Pi + Neovim + Zellij).

`agent-console` launches a zellij workspace with:
- main pane: Pi
- right pane: Neovim (`--listen $NVIM_LISTEN_ADDRESS`)

## Runtime

The launcher creates a temp runtime dir using:
- `mktemp -d /tmp/agent-console.XXXXXX`

Exports:
- `AGENT_CONSOLE_RUNTIME_DIR`
- `NVIM_LISTEN_ADDRESS=$AGENT_CONSOLE_RUNTIME_DIR/nvim.sock`

## Config (flake module)

Use `flakeModules.agent-console` and set `devtools.agent-console` options:
- `resumeMode` (`auto|new|resume`)
- `piArgs`
- `piExtensions`
- `rightPaneWidth`
- `startNvimCollapsed`
- `projectRootMode` (`cwd|git-root`)

## Troubleshooting

- **Neovim actions fail from Pi tools**
  - Ensure `NVIM_LISTEN_ADDRESS` is set in the session.
  - Ensure Neovim is running in the right pane.
- **RPC timeout errors**
  - Neovim may be restarting or blocked; retry.
- **`nvim executable not found`**
  - Ensure Neovim package is included in `agent-console` configuration.
