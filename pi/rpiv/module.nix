{ ... }:
let
  packageNames = [
    "rpiv-advisor"
    "rpiv-args"
    "rpiv-ask-user-question"
    "rpiv-btw"
    "rpiv-i18n"
    "rpiv-pi"
    "rpiv-todo"
    "rpiv-voice"
    "rpiv-warp"
    "rpiv-web-tools"
  ];
in
{
  config = {
    perSystem = { pkgs, lib, ... }:
      let
        rpivMono = pkgs.callPackage ./rpiv-mono.nix { };
        rpivPackages = lib.listToAttrs (map (
          name:
          {
            name = "rpiv-${name}";
            value = pkgs.symlinkJoin {
              name = "rpiv-${name}-package";
              paths = [ "${rpivMono}/lib/node_modules/rpiv-mono/packages/${name}" ];
            };
          }
        ) packageNames);
      in
      {
        packages = { rpiv-mono = rpivMono; } // rpivPackages;
      };
  };
}
