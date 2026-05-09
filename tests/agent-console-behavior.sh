#!/usr/bin/env bash
set -euo pipefail

AGENT_CONSOLE_BIN="${AGENT_CONSOLE_BIN:-$(nix build .#agent-console --print-out-paths --no-link)/bin/agent-console}"

SCRIPT_PATH="$(readlink -f "$AGENT_CONSOLE_BIN")"

assert_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" "$SCRIPT_PATH"; then
    echo "Missing expected content in built agent-console script: $needle" >&2
    exit 1
  fi
}

# Startup model: Pi starts fullscreen, Neovim hidden but running
assert_contains "action toggle-fullscreen"
assert_contains ".pi-fullscreen-applied"

# Keybindings are generated in immutable nix-store zellij config
CONFIG_PATH="$(grep -Eo '/nix/store/[^ ]*agent-console-zellij-config.kdl' "$SCRIPT_PATH" | head -n1)"
if [ -z "$CONFIG_PATH" ] || [ ! -f "$CONFIG_PATH" ]; then
  echo "Could not locate generated zellij config path in built script" >&2
  exit 1
fi

grep -Fq 'bind "F6"' "$CONFIG_PATH"
grep -Fq 'bind "F7"' "$CONFIG_PATH"
grep -Fq 'bind "F8"' "$CONFIG_PATH"

if grep -Fq 'bind "Ctrl g"' "$CONFIG_PATH"; then
  echo "Unexpected Ctrl-g binding in generated zellij config" >&2
  exit 1
fi

# Session env wiring for extension -> zellij actions
assert_contains 'export AGENT_CONSOLE_SESSION="$SESSION_NAME"'

echo "agent-console behavior test passed"
