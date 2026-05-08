#!/usr/bin/env bash
set -euo pipefail

SESSION="agent-console-smoke-$(date +%s)"
OUT_DIR="/tmp/$SESSION"
mkdir -p "$OUT_DIR"

AGENT_CONSOLE_BIN="$(nix build .#agent-console --print-out-paths --no-link)/bin/agent-console"
ZELLIJ_BIN="$(nix build .#zellij --print-out-paths --no-link)/bin/zellij"

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

# Dismiss startup tips overlay if present.
"$ZELLIJ_BIN" --session "$SESSION" action write 27 || true
sleep 0.3

# Start suspended panes (zellij command panes can start suspended by default).
"$ZELLIJ_BIN" --session "$SESSION" action move-focus down || true
"$ZELLIJ_BIN" --session "$SESSION" action write 13 || true
"$ZELLIJ_BIN" --session "$SESSION" action move-focus right || "$ZELLIJ_BIN" --session "$SESSION" action focus-next-pane
"$ZELLIJ_BIN" --session "$SESSION" action write 13 || true
sleep 0.5

"$ZELLIJ_BIN" --session "$SESSION" action dump-layout > "$OUT_DIR/layout.kdl"

# Capture multiple focus states to reliably include shell panes and plugin panes.
for i in 1 2 3 4 5; do
  "$ZELLIJ_BIN" --session "$SESSION" action dump-screen "$OUT_DIR/pane-$i.txt"
  "$ZELLIJ_BIN" --session "$SESSION" action focus-next-pane || true
done

# Assertions: at least one captured pane should look Pi-ish and one Neovim-ish.
PI_RE='Press ctrl\+o|model|session|/help|pi'
NVIM_RE='\[No Name\]| NORMAL |nvim|NVIM'

if ! grep -Eqs "$PI_RE" "$OUT_DIR"/pane-*.txt; then
  echo "Could not detect Pi output in captured panes" >&2
  for f in "$OUT_DIR"/pane-*.txt; do echo "--- $f ---"; cat "$f"; done
  exit 1
fi

if ! grep -Eqs "$NVIM_RE" "$OUT_DIR"/pane-*.txt; then
  echo "Could not detect Neovim output in captured panes" >&2
  for f in "$OUT_DIR"/pane-*.txt; do echo "--- $f ---"; cat "$f"; done
  exit 1
fi

echo "agent-console smoke test passed"
echo "artifacts: $OUT_DIR"
