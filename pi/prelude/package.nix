{ pkgs, lib, features ? { } }:
let
  feature = path: default:
    let value = lib.attrByPath path default features;
    in value;

  disabledPreludeExtensions =
    (lib.optional (!(feature [ "mode" "enable" ] true)) "mode.ts")
    ++ (lib.optional (!(feature [ "status" "enable" ] true)) "status.ts")
    ++ (lib.optional (!(feature [ "guardrails" "enable" ] true)) "guardrails.ts")
    ++ (lib.optional (!(feature [ "tools" "ask" "enable" ] true)) "tools-ask.ts")
    ++ (lib.optional (!(feature [ "tools" "todo" "enable" ] true)) "tools-todo.ts")
    ++ (lib.optional (!(feature [ "tools" "web" "enable" ] true)) "tools-web.ts");
in
pkgs.runCommand "pi-prelude-package" { } ''
  mkdir -p "$out/pi-prelude"
  cp -R ${./.}/. "$out/pi-prelude/"
  chmod -R u+w "$out/pi-prelude"
  ${lib.concatMapStringsSep "\n" (file: "rm -f \"$out/pi-prelude/extensions/${file}\"") disabledPreludeExtensions}
  cat > "$out/package.json" <<'EOF'
  ${builtins.toJSON {
    name = "pi-prelude";
    private = true;
    keywords = [ "pi-package" ];
    pi = { extensions = [ "./pi-prelude/extensions" ]; };
  }}
  EOF
''
