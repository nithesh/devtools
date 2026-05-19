#!/usr/bin/env bash
set -euo pipefail

: "${PI_PRELUDE_BIN:?PI_PRELUDE_BIN is required}"
: "${PI_PRELUDE_PACKAGE_DIR:?PI_PRELUDE_PACKAGE_DIR is required}"

if [[ ! -x "$PI_PRELUDE_BIN" ]]; then
  echo "pi-prelude wrapper not executable: $PI_PRELUDE_BIN" >&2
  exit 1
fi

if [[ ! -d "$PI_PRELUDE_PACKAGE_DIR" ]]; then
  echo "pi-prelude package dir missing: $PI_PRELUDE_PACKAGE_DIR" >&2
  exit 1
fi

# Wrapper should load one packaged source path via --extension.
if ! grep -q -- "--extension" "$PI_PRELUDE_BIN"; then
  echo "pi-prelude wrapper missing --extension flag" >&2
  exit 1
fi

if ! grep -q -- "$PI_PRELUDE_PACKAGE_DIR" "$PI_PRELUDE_BIN"; then
  echo "pi-prelude wrapper does not reference packaged prelude path" >&2
  exit 1
fi

# Packaged source should contain package manifest + implemented extensions.
for f in \
  package.json \
  extensions/mode.ts \
  extensions/status.ts \
  extensions/tools-ask.ts \
  extensions/tools-todo.ts
 do
  if [[ ! -f "$PI_PRELUDE_PACKAGE_DIR/$f" ]]; then
    echo "missing prelude artifact: $f" >&2
    exit 1
  fi
 done

# Basic contract checks: expected tools/commands registered.
if ! grep -q 'name: "ask_user"' "$PI_PRELUDE_PACKAGE_DIR/extensions/tools-ask.ts"; then
  echo "tools-ask.ts missing ask_user registration" >&2
  exit 1
fi

if ! grep -q 'name: "todo"' "$PI_PRELUDE_PACKAGE_DIR/extensions/tools-todo.ts"; then
  echo "tools-todo.ts missing todo registration" >&2
  exit 1
fi

if ! grep -q 'registerCommand("mode"' "$PI_PRELUDE_PACKAGE_DIR/extensions/mode.ts"; then
  echo "mode.ts missing /mode command registration" >&2
  exit 1
fi

echo "pi-prelude wiring check passed"
