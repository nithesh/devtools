#!/usr/bin/env bash
set -euo pipefail

EXT="${EXT_PATH:-agent-console/extensions/nvim-rpc.ts}"

grep -Fq 'name: "agent_console_start_review"' "$EXT"
grep -Fq 'await ensureNvimVisibleInSplitMode();' "$EXT"
grep -Fq 'await zellijAction(["move-focus", "right"]);' "$EXT"

echo "agent-console extension test passed"
