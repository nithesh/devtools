#!/usr/bin/env bash
set -euo pipefail

SESSION="agent-console-smoke-$(date +%s)"
OUT_DIR="/tmp/$SESSION"
mkdir -p "$OUT_DIR"

AGENT_CONSOLE_BIN="${AGENT_CONSOLE_BIN:-$(nix build .#agent-console --print-out-paths --no-link)/bin/agent-console}"
ZELLIJ_BIN="${ZELLIJ_BIN:-$(nix build .#zellij --print-out-paths --no-link)/bin/zellij}"

# Launch in a PTY so zellij can start in CI/headless environments.
AGENT_CONSOLE_SESSION="$SESSION" timeout 20s \
  script -qefc "$AGENT_CONSOLE_BIN" "$OUT_DIR/pty.log" >/dev/null 2>&1 &
LAUNCH_PID=$!

cleanup() {
  set +e
  "$ZELLIJ_BIN" --session "$SESSION" action close-tab >/dev/null 2>&1 || true
  "$ZELLIJ_BIN" kill-session "$SESSION" >/dev/null 2>&1 || true
  kill "$LAUNCH_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Wait for session to come up.
for _ in $(seq 1 40); do
  if "$ZELLIJ_BIN" list-sessions | grep -q "$SESSION"; then
    break
  fi
  sleep 0.25
done

if ! "$ZELLIJ_BIN" list-sessions | grep -q "$SESSION"; then
  echo "Session did not start: $SESSION" >&2
  exit 1
fi

"$ZELLIJ_BIN" --session "$SESSION" action dump-layout > "$OUT_DIR/layout.kdl"

# Assertions on effective runtime layout:
# - vertical split (left/right)
# - one Pi command pane
# - one Neovim command pane
if ! grep -q 'split_direction="vertical"' "$OUT_DIR/layout.kdl"; then
  echo "Expected vertical split in runtime layout" >&2
  cat "$OUT_DIR/layout.kdl"
  exit 1
fi

if ! grep -Eq 'command=".*pi-coding-agent|command=".*/bin/pi"|command="pi"' "$OUT_DIR/layout.kdl"; then
  echo "Expected Pi command pane in runtime layout" >&2
  cat "$OUT_DIR/layout.kdl"
  exit 1
fi

if ! grep -Eq 'command=".*/bin/nvim"|command="nvim"' "$OUT_DIR/layout.kdl"; then
  echo "Expected Neovim command pane in runtime layout" >&2
  cat "$OUT_DIR/layout.kdl"
  exit 1
fi

# Ensure key layout actions are callable in the session.
"$ZELLIJ_BIN" --session "$SESSION" action move-focus right
"$ZELLIJ_BIN" --session "$SESSION" action move-focus left
"$ZELLIJ_BIN" --session "$SESSION" action toggle-fullscreen
"$ZELLIJ_BIN" --session "$SESSION" action toggle-fullscreen

echo "agent-console smoke test passed"
echo "artifacts: $OUT_DIR"
