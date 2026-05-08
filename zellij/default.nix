{pkgs, package ? pkgs.zellij, configFile ? ./config.kdl}:
pkgs.writeShellScriptBin "zellij-devtools" ''
  exec ${package}/bin/zellij --config ${configFile} "$@"
''
