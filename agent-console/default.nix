{
  pkgs,
  piPackage,
  neovimPackage,
  zellijPackage,
  zellijConfigFile,
  resumeMode ? "auto",
  piArgs ? [ ],
  piExtensions ? [ ],
  rightPaneWidth ? 35,
  startNvimCollapsed ? true,
  projectRootMode ? "cwd",
  appendAgentConsoleSystemPrompt ? true,
}:
let
  lib = pkgs.lib;
  clampedRightPaneWidth =
    if rightPaneWidth < 10 then 10
    else if rightPaneWidth > 80 then 80
    else rightPaneWidth;
  rightWidth = clampedRightPaneWidth;
  mainWidth = 100 - rightWidth;
  resumeArgs =
    if resumeMode == "resume" then [ "--resume" ]
    else if resumeMode == "new" then [ "--new" ]
    else [ "--continue" ];
  extensionArgs = lib.concatMap (p: [ "--extension" (toString p) ]) piExtensions;

  agentConsolePromptFile = pkgs.writeText "agent-console-system-prompt.md" ''
You are running inside agent-console (Pi + Neovim + Zellij).

Use Neovim as a visual collaboration surface.
When the user needs to inspect code, call agent_console_start_review once to reveal Neovim and open the relevant file/diff.
After that, do not repeatedly manipulate layout/focus unless asked.
Always tell the user what you opened and that they can keep chatting while Neovim stays visible.
'';

  promptArgs =
    if appendAgentConsoleSystemPrompt
    then [ "--append-system-prompt" (toString agentConsolePromptFile) ]
    else [ ];

  allPiArgs = resumeArgs ++ extensionArgs ++ promptArgs ++ piArgs;
  piArgsShell = lib.concatStringsSep " " (map lib.escapeShellArg allPiArgs);

  piBin = "${piPackage}/bin/pi";
  nvimBin = "${neovimPackage}/bin/nvim";
  mergedZellijConfig = pkgs.writeText "agent-console-zellij-config.kdl" ''
${builtins.readFile zellijConfigFile}
keybinds {
  shared_except "locked" {
    bind "F6" { MoveFocus "Left"; }
    bind "F7" { MoveFocus "Right"; }
    bind "F8" { ToggleFocusFullscreen; }
  }
}
'';
in
pkgs.writeShellScriptBin "agent-console" ''
  set -euo pipefail

  SESSION_NAME="''${AGENT_CONSOLE_SESSION:-agent-console-$(date +%s)}"

  RUNTIME_DIR="$(mktemp -d /tmp/agent-console.XXXXXX)"
  export AGENT_CONSOLE_RUNTIME_DIR="$RUNTIME_DIR"
  export NVIM_LISTEN_ADDRESS="$RUNTIME_DIR/nvim.sock"
  export AGENT_CONSOLE_SESSION="$SESSION_NAME"

  cleanup() {
    rm -rf "$RUNTIME_DIR"
  }
  trap cleanup EXIT INT TERM

  if [ "${projectRootMode}" = "git-root" ] && command -v git >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    cd "$root"
  fi

  cat > "$RUNTIME_DIR/pi-launch.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [ "${if startNvimCollapsed then "true" else "false"}" = "true" ] && [ ! -e "$AGENT_CONSOLE_RUNTIME_DIR/.pi-fullscreen-applied" ]; then
  ${zellijPackage}/bin/zellij --session "$AGENT_CONSOLE_SESSION" action toggle-fullscreen >/dev/null 2>&1 || true
  touch "$AGENT_CONSOLE_RUNTIME_DIR/.pi-fullscreen-applied"
fi

exec ${piBin} ${piArgsShell} "$@"
SH
  chmod +x "$RUNTIME_DIR/pi-launch.sh"

  cat > "$RUNTIME_DIR/layout.kdl" <<KDL
layout {
    pane split_direction="vertical" {
        pane size="${toString mainWidth}%" borderless=true command="$RUNTIME_DIR/pi-launch.sh"
        pane size="${toString rightWidth}%" borderless=true command="${nvimBin}" {
            args "--listen" "$NVIM_LISTEN_ADDRESS"
        }
    }
    pane size=1 borderless=true {
        plugin location="zellij:status-bar"
    }
}
KDL

  exec ${zellijPackage}/bin/zellij --session "$SESSION_NAME" --config ${mergedZellijConfig} --new-session-with-layout "$RUNTIME_DIR/layout.kdl" "$@"
''
