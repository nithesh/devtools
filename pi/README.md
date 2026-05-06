# Pi Module

Declarative, multi-layer configuration for the [Pi](https://github.com/badlogic/pi-mono) AI coding agent.

## Design Principles

1. **Immutable global config**: Home Manager owns the user's baseline. Pi's self-mutation commands (`install`, `remove`, `config`, `update`) are not used; all changes go through Nix.
2. **Project overlays**: A per-project wrapper (via flake module) layers additional model, resource, and prompt overrides on top of the global baseline.
3. **No temp directories**: The wrapper uses Pi's native CLI args and environment variables. No config merging, no JSON rewriting, no ephemeral state.
4. **XDG compliance**: Global config lives under `~/.config/pi/agent/` (not `~/.pi/agent/`).

## Architecture

```
Layer 1 ──► packages.${system}.pi-unwrapped
  Plain upstream Pi from llm-agents.nix. No configuration.

Layer 2 ──► packages.${system}.pi (flake module wrapper)
  Shell script that invokes pi-unwrapped with CLI flags and env vars.
  Used in project devShells.

Layer 3 ──► programs.pi (Home Manager module)
  Installs pi-unwrapped and writes immutable global config files.
  Exports env vars so Pi discovers the XDG config path.
```

## Config Precedence (low → high)

```
1. Pi defaults
2. Home Manager global config    (~/.config/pi/agent/settings.json)
3. Project .pi/settings.json     (if present in cwd; Pi native override)
4. Flake module CLI overrides    (--model, --extension, --skill, etc.)
5. Explicit CLI / env vars       (user types them at shell)
```

Note: scalar overrides (`--model`, `--provider`, `--thinking`) **replace** the global value.
Resource flags (`--extension`, `--skill`, etc.) are **additive** — global resources are still discovered unless `--no-*` is used.

## What the wrapper can and cannot do

| Config | CLI arg available? | Wrapper support |
|--------|-------------------|-----------------|
| `defaultModel` | `--model` | ✅ Override |
| `defaultProvider` | `--provider` | ✅ Override |
| `defaultThinkingLevel` | `--thinking` | ✅ Override |
| `theme` (built-in name) | ❌ No `--theme-name` | ⚠️ Use HM or `.pi/settings.json` |
| `theme` (custom file) | `--theme <path>` | ✅ Load custom theme file |
| `extensions` | `--extension <path>` | ✅ Additive |
| `skills` | `--skill <path>` | ✅ Additive |
| `prompts` | `--prompt-template <path>` | ✅ Additive |
| `compaction.*` | ❌ | ⚠️ Use HM or `.pi/settings.json` |
| `steeringMode` | ❌ | ⚠️ Use HM or `.pi/settings.json` |
| `followUpMode` | ❌ | ⚠️ Use HM or `.pi/settings.json` |
| `transport` | ❌ | ⚠️ Use HM or `.pi/settings.json` |
| `AGENTS.md` | `--append-system-prompt` | ✅ Approximate (appended to system prompt) |
| `SYSTEM.md` | `--system-prompt` | ✅ Replaces default prompt |

Settings without CLI args must be managed via Home Manager (global) or a project `.pi/settings.json` (local).

## Usage

### 1. Home Manager — global baseline

```nix
# In your home-manager flake
imports = [ inputs.devtools.homeManagerModules.pi ];

programs.pi = {
  enable = true;

  # Optional: override which package is installed (default: pi-unwrapped)
  # package = pkgs.pi-unwrapped;

  settings = {
    defaultProvider = "anthropic";
    defaultModel = "claude-sonnet-4-20250514";
    theme = "dark";
    compaction = {
      enabled = true;
      reserveTokens = 16384;
    };
    steeringMode = "one-at-a-time";
    followUpMode = "one-at-a-time";
    transport = "sse";
  };

  # Global AGENTS.md — loaded for every session
  agentsMd = '''
    You are an expert Nix developer.
    Prefer modern nix (nixpkgs.lib) idioms.
    Use flake-parts for flake structure.
  ''';
};
```

The HM module writes:
- `~/.config/pi/agent/settings.json` (immutable symlink to store)
- `~/.config/pi/agent/AGENTS.md`
- exports `PI_CODING_AGENT_DIR = ~/.config/pi/agent`
- exports `PI_CODING_AGENT_SESSION_DIR = ~/.pi/agent/sessions` (preserves sessions outside XDG)

Because `settings.json` is a store symlink, Pi's mutating commands (like `/model`, `/settings`) 
will fail with permission errors when trying to write changes. This is intentional — the config is 
fully declarative and managed by Nix.

### 2. Flake Module — project overlay

Import the flake module:

```nix
# In your project's flake.nix
imports = [ inputs.devtools.flakeModules.pi ];

perSystem = { config, ... }: {
  devtools.pi = {
    enable = true;

    # Model override for this project
    model = "openai/gpt-4o";
    provider = "openai";
    thinking = "medium";

    # Project-specific resources (nix store paths)
    extensions = [ ./pi/extensions/my-ext.ts ];
    skills = [ ./pi/skills ];
    themes = [ ./pi/themes/custom.json ];
    prompts = [ ./pi/prompts ];

    # Project-specific system prompt appended to global
    appendSystemPrompt = ''
      This is a Rust web service using Axum and SQLx.
      Prefer async/await patterns and serde for serialization.
    '';

    # Block all tool use (read-only mode)
    # tools = [ "read" "grep" "find" "ls" ];

    # Disable global extension discovery, only use explicit ones
    # noExtensions = true;
  };

  devShells.default = pkgs.mkShell {
    packages = [ config.packages.pi ];
  };
};
```

This produces `packages.pi`: a wrapper script around `pi-unwrapped`.

Example of what the wrapper script generates:

```bash
#!/bin/sh
export PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.config/pi/agent}"
export PI_CODING_AGENT_SESSION_DIR="${PI_CODING_AGENT_SESSION_DIR:-$HOME/.pi/agent/sessions}"

# Block mutating commands
case "$1" in
  install|remove|uninstall|update|config)
    echo "error: '$1' is disabled in the wrapped Pi." >&2
    echo "       Manage resources declaratively in your flake or Home Manager." >&2
    exit 1
    ;;
esac

exec /nix/store/...-pi-unwrapped/bin/pi \
  --model "openai/gpt-4o" \
  --provider "openai" \
  --thinking "medium" \
  --extension /nix/store/.../my-ext.ts \
  --skill /nix/store/.../skills \
  --theme /nix/store/.../custom.json \
  --prompt-template /nix/store/.../prompts \
  --append-system-prompt "This is a Rust web service..." \
  "$@"
```

### 3. Combined — HM baseline + project overlay

```
┌──────────────────────────────────┐
│ Home Manager (everywhere)        │
│   model: claude-sonnet           │
│   theme: dark                    │
│   AGENTS.md: Nix expert          │
│   extensions: []                 │
├──────────────────────────────────┤
│ Project devShell                 │
│   --model gpt-4o                 │ ← replaces HM model
│   --extension ./project-ext.ts   │ ← added to global exts
│   --skill ./project-skills/      │ ← added to global skills
│   --append-system-prompt "..."   │ ← appended to prompt
└──────────────────────────────────┘
```

## Options Reference

### Flake module (`devtools.pi`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | `bool` | `false` | Enable the pi wrapper package |
| `model` | `nullOr str` | `null` | `--model` override |
| `provider` | `nullOr str` | `null` | `--provider` override |
| `thinking` | `nullOr str` | `null` | `--thinking` override (`off/minimal/low/medium/high/xhigh`) |
| `models` | `listOf str` | `[]` | `--models` patterns for Ctrl+P cycling |
| `extensions` | `listOf path` | `[]` | `--extension` paths |
| `skills` | `listOf path` | `[]` | `--skill` paths |
| `themes` | `listOf path` | `[]` | `--theme` paths (custom theme files) |
| `prompts` | `listOf path` | `[]` | `--prompt-template` paths |
| `tools` | `nullOr (listOf str)` | `null` | `--tools` allowlist |
| `noBuiltinTools` | `bool` | `false` | `--no-builtin-tools` |
| `noTools` | `bool` | `false` | `--no-tools` |
| `noExtensions` | `bool` | `false` | `--no-extensions` |
| `noSkills` | `bool` | `false` | `--no-skills` |
| `noThemes` | `bool` | `false` | `--no-themes` |
| `noPrompts` | `bool` | `false` | `--no-prompt-templates` |
| `noContextFiles` | `bool` | `false` | `--no-context-files` |
| `systemPrompt` | `nullOr str` | `null` | `--system-prompt` (replaces default prompt) |
| `appendSystemPrompt` | `nullOr str` | `null` | `--append-system-prompt` (appended to prompt) |
| `offline` | `bool` | `false` | `--offline` |
| `verbose` | `bool` | `false` | `--verbose` |


### Home Manager module (`programs.pi`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | `bool` | `false` | Enable Pi installation |
| `package` | `package` | `pi-unwrapped` | Pi package to install |
| `settings` | `attrs` | `{}` | Global settings.json content |
| `agentsMd` | `nullOr str` | `null` | Global AGENTS.md content |
| `systemMd` | `nullOr str` | `null` | Global SYSTEM.md content |
| `appendSystemMd` | `nullOr str` | `null` | Global APPEND_SYSTEM.md content |

## Notes

### XDG Config Directory

Pi's default agent directory is `~/.pi/agent`. This module uses XDG (`~/.config/pi/agent`) instead.
The wrapper and HM module both export `PI_CODING_AGENT_DIR` so Pi discovers the correct path.

Sessions are preserved outside XDG at `~/.pi/agent/sessions/` via `PI_CODING_AGENT_SESSION_DIR`.

### Mutating Commands and Interactive Configuration

With Home Manager-managed immutable configuration, Pi's interactive configuration
commands (`/model`, `/settings`, `pi config`, etc.) will fail with permission errors
when trying to write changes to `settings.json`.

This is an intentional trade-off to maintain fully declarative configuration.
To change settings, edit your Nix expressions and re-apply Home Manager.

For interactive experimentation, use project-level `.pi/settings.json` files
which take precedence over global HM config.

### Secrets

Do **not** put API keys in `settings` or `systemPrompt` — they will end up in the Nix store.

Use environment variables (e.g. `ANTHROPIC_API_KEY`) or secret management tools (sops-nix, agenix).
The HM module can export env vars from secret files without putting them in the store.

### Project `.pi/settings.json`

If a project has its own `.pi/settings.json`, Pi will merge it on top of global settings.
The wrapper CLI args then apply on top of that.
This is Pi's native behavior and should "just work".
