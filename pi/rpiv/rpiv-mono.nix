{ pkgs }:

pkgs.buildNpmPackage rec {
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
}
