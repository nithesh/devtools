# pi-prelude

Nix-first baseline for Pi in this repo, located at `pi/prelude/`.

## What it includes

- Flake module + package wiring for an opinionated Pi profile
- Spec-first workflow docs under `docs/pi/prelude/`
- Runtime artifacts (extensions/prompts/skills) are added incrementally as implemented

## Flake module usage

```nix
{
  imports = [ inputs.devtools.flakeModules.pi-prelude ];

  perSystem = { config, ... }: {
    devtools.pi.prelude.enable = true;

    # optional overrides
    # devtools.pi.prelude.extraArgs.model = "anthropic/claude-sonnet-4-5";
  };
}
```

Package output: `packages.pi-prelude`

## Secondary (non-Nix) packaging

A `package.json` is included so this can also be consumed via `pi install`.
