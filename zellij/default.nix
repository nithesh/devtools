{pkgs, package ? pkgs.zellij, configFile ? ./config.kdl}:
pkgs.writeShellScriptBin "zellij" ''
  exec ${package}/bin/zellij --config ${configFile} "$@"
''
