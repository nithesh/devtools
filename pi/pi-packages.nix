{ pkgs, lib }:
let
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
    name:
    {
      name = lib.removePrefix "rpiv-" name;
      value = pkgs.symlinkJoin {
        name = "rpiv-${name}-package";
        paths = [ "${rpivMono}/lib/node_modules/rpiv-mono/packages/${name}" ];
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

  whatsapp = pkgs.symlinkJoin {
    name = "whatsapp-pi-package";
    paths = [ "${whatsappSrc}/lib/node_modules/whatsapp-pi" ];
  };
in
{
  rpiv = rpiv // { mono = rpivMono; };
  whatsappPi = whatsapp;
}
