{
  pkgs,
  config ? {},
}: let
  tomlFormat = pkgs.formats.toml {};
  configFile = tomlFormat.generate "config.toml" config;
  package = pkgs.writeShellScriptBin "hx" ''
    ${pkgs.helix}/bin/hx --config ${configFile} $@
  '';
in
  package
