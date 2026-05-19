# pi-prelude

Nix-first baseline for Pi in this repo, located at `pi/prelude/`.

## What it includes

- Flake module + package wiring for an opinionated Pi profile
- A dedicated derivation `packages.pi-prelude-package` containing only `pi/prelude/`
- Pi loads prelude resources from that package path via a single `--extension <package-dir>` source
- Spec-first workflow docs under `docs/pi/prelude/`

## Flake module usage

```nix
{
  imports = [ inputs.devtools.flakeModules.pi-prelude ];

  perSystem = { config, ... }: {
    devtools.pi.prelude.enable = true;

    # optional overrides
    # devtools.pi.prelude.extraArgs.model = "anthropic/claude-sonnet-4-5";
    # devtools.pi.prelude.extraExtensionSources = [ ./my-extension.ts ];
  };
}
```

Package output: `packages.pi-prelude`

## Secondary (non-Nix) packaging

A `package.json` is included so this can also be consumed via `pi install`.
