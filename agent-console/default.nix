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
  startNvimCollapsed ? false,
  projectRootMode ? "cwd",
}:
let
  lib = pkgs.lib;
  clampedRightPaneWidth =
    if rightPaneWidth < 10 then 10
    else if rightPaneWidth > 80 then 80
    else rightPaneWidth;
  rightWidth = if startNvimCollapsed then 1 else clampedRightPaneWidth;
  mainWidth = 100 - rightWidth;
  resumeArgs =
    if resumeMode == "resume" then [ "--resume" ]
    else if resumeMode == "new" then [ "--new" ]
    else [ ];
  extensionArgs = lib.concatMap (p: [ "--extension" (toString p) ]) piExtensions;
  allPiArgs = resumeArgs ++ extensionArgs ++ piArgs;
  piCmd = lib.concatStringsSep " " (map lib.escapeShellArg ([ "${piPackage}/bin/pi" ] ++ allPiArgs));
  nvimBin = "${neovimPackage}/bin/nvim";
in
pkgs.writeShellScriptBin "agent-console" ''
  set -euo pipefail

  RUNTIME_DIR="$(mktemp -d /tmp/agent-console.XXXXXX)"
  export AGENT_CONSOLE_RUNTIME_DIR="$RUNTIME_DIR"
  export NVIM_LISTEN_ADDRESS="$RUNTIME_DIR/nvim.sock"

  cleanup() {
    rm -rf "$RUNTIME_DIR"
  }
  trap cleanup EXIT INT TERM

  if [ "${projectRootMode}" = "git-root" ] && command -v git >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    cd "$root"
  fi

  cat > "$RUNTIME_DIR/layout.kdl" <<KDL
layout {
    default_tab_template {
        pane split_direction="horizontal" {
            pane size="${toString mainWidth}%" borderless=true {
                command "sh"
                args "-lc"
                args "${piCmd}"
            }
            pane size="${toString rightWidth}%" borderless=true {
                command "${nvimBin}"
                args "--listen"
                args "$NVIM_LISTEN_ADDRESS"
            }
        }
        pane size=1 borderless=true {
            plugin location="zellij:status-bar"
        }
    }
}
KDL

  exec ${zellijPackage}/bin/zellij --config ${zellijConfigFile} --layout "$RUNTIME_DIR/layout.kdl"
''
