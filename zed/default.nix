{
  pkgs,
  settings ? {},
}: let
  jsonFormat = pkgs.formats.json {};
  settingsFile = jsonFormat.generate "settings.json" settings;

  # Create a config directory with the settings file
  configDir = pkgs.runCommand "zed-config" {} ''
    mkdir -p $out/zed
    cp ${settingsFile} $out/zed/settings.json
  '';

  # Wrapper script that sets XDG_CONFIG_HOME to use our config
  package = pkgs.writeShellScriptBin "zed" ''
    export XDG_CONFIG_HOME=${configDir}
    exec ${pkgs.zed-editor}/bin/zeditor "$@"
  '';
in
  package
