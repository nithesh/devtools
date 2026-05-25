{ ... }:
{
  config = {
    perSystem = { pkgs, ... }: {
      packages.whatsapp-pi = pkgs.runCommand "whatsapp-pi-package"
        {
          src = pkgs.fetchurl {
            url = "https://registry.npmjs.org/whatsapp-pi/-/whatsapp-pi-1.0.62.tgz";
            hash = "sha256-/p0dfZS5R8PMUGMVcLRiwD2AkIc7nUtgxjTj4brb/V4=";
          };
        }
        ''
          mkdir -p "$out"
          tar -xzf "$src" --strip-components=1 -C "$out"
        '';
    };
  };
}
