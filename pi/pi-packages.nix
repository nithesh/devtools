{ pkgs, lib }:
let
  mkPiPackage = { name, src, extensions ? [ "./${name}" ] }:
    pkgs.runCommand "${name}-package" { } ''
      mkdir -p "$out"
      ln -s ${src} "$out/${name}"
      cat > "$out/package.json" <<'EOF'
      ${builtins.toJSON {
        inherit name;
        private = true;
        keywords = [ "pi-package" ];
        pi = { inherit extensions; };
      }}
      EOF
    '';

  rpivPackageNames = [
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

  rpivMono = pkgs.buildNpmPackage rec {
    pname = "rpiv-mono";
    version = "1.12.0";

    src = pkgs.fetchFromGitHub {
      owner = "juicesharp";
      repo = "rpiv-mono";
      rev = "c1df0a5ccf4422785c3d73ec92aabaaf29e4a9be";
      hash = "sha256-Z1Fq1f8b46JYQ1+RE5JxGY9kvh3SW7I8DcNA0GDre0k=";
    };

    npmDepsHash = "sha256-VBVh+35yTIRGOCnCHoer0o7g1NgLFFPtwstqhVnruiI=";

    dontNpmBuild = true;
  };

  rpiv = lib.listToAttrs (map (
    packageName:
    let
      name = lib.removePrefix "rpiv-" packageName;
      cleanName = packageName;
    in
    {
      inherit name;
      value = mkPiPackage {
        name = cleanName;
        src = "${rpivMono}/lib/node_modules/rpiv-mono/packages/${packageName}";
        extensions = [ "./${cleanName}/index.ts" ];
      };
    }
  ) rpivPackageNames);

  whatsappSrc = pkgs.buildNpmPackage rec {
    pname = "whatsapp-pi";
    version = "master-2026-05-20";

    src = pkgs.fetchFromGitHub {
      owner = "RaphaCastelloes";
      repo = "whatsapp-pi";
      rev = "6f991256bd6eb20b0ab3c09952b6e65bbaa30058";
      hash = "sha256-lo/wHpj4K6vaqbnDpjmXjLa6r6lakLRaz2xcGD148yM=";
    };

    npmDepsHash = "sha256-tixoIekexhbuBEd50YyUOgw1ODn7dUF7rKItb6VWUxA=";
    makeCacheWritable = true;
    dontNpmBuild = true;
  };

  whatsapp = mkPiPackage {
    name = "whatsapp-pi";
    src = "${whatsappSrc}/lib/node_modules/whatsapp-pi";
    extensions = [ "./whatsapp-pi/whatsapp-pi.ts" ];
  };
in
{
  rpiv = rpiv // { mono = rpivMono; };
  whatsappPi = whatsapp;
}
