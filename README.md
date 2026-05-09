# Nithesh's Development Tools

A Nix Flake-based collection of pre-configured editor setups and AI tools for modern software development. This project provides declarative, reproducible development environments using Nix, making it easy to maintain consistent setups across machines.

## Features

- **Declarative Configuration**: All settings defined as Nix expressions
- **Reproducible Builds**: Consistent setup across different systems
- **Modular Architecture**: Clean separation of configurations
- **LSP Support**: Built-in language server support for Nix and other languages
- **AI Coding Agent**: Integrated pi with customizable prompts and skills
- **Auto-formatting**: Integrated formatters (alejandra for Nix)

## Available Tools

### 🎯 Helix
Modern modal editor with built-in LSP support.

**Features:**
- Dracula at Night theme
- Multiple bufferlines
- Relative line numbers
- Nix language support with alejandra formatter

### 🚀 Neovim (via nixvim)
Highly customizable editor with comprehensive plugin ecosystem.

**Features:**
- OneDark colorscheme
- Full LSP setup (lua_ls, nil_ls)
- Completion with nvim-cmp
- Telescope fuzzy finder
- Git integration (gitgutter, lazygit)
- Tree-sitter syntax highlighting
- File explorer (nvim-tree)
- Terminal integration (toggleterm)

### ⚡ Zed
Fast, collaborative code editor built on modern technologies.

**Features:**
- One Dark theme
- Nix LSP support (nil) with alejandra formatter
- Auto-save and format-on-save
- Git integration with inline blame
- Relative line numbers
- Privacy-focused (telemetry disabled)

### 🤖 Pi (AI Coding Agent)
Customizable AI coding harness with support for extensions, skills, themes, and prompt templates.

**Features:**
- Customizable settings (model, theme, behavior)
- Extension/Skill/Theme support via environment paths
- Global AGENTS.md support
- Home Manager module for declarative configuration

## Requirements

- [Nix](https://nixos.org/download.html) with flakes enabled
- Linux (x86_64-linux or aarch64-linux)

### Enabling Flakes

Add to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

## Usage

### Quick Start with Dev Shell

Enter a development shell with all editors available:

```bash
nix develop
```

This provides:
- `hx` - Helix editor
- `zed` - Zed editor
- `pi` - AI coding agent
- `nil` - Nix language server
- `alejandra` - Nix formatter

### Building Individual Tools

Build a specific tool package:

```bash
# Build Helix
nix build .#helix

# Build Neovim
nix build .#neovim

# Build Zed
nix build .#zed

# Build Pi
nix build .#pi
```

Run the built tool:

```bash
./result/bin/hx      # Helix
./result/bin/nvim    # Neovim
./result/bin/zed     # Zed
./result/bin/pi      # Pi AI agent
```

### Running Directly

Run a tool without building:

```bash
nix run .#helix
nix run .#neovim
nix run .#zed
nix run .#pi
```

## Project Structure

```
.
├── flake.nix              # Main flake configuration
├── flake.lock             # Locked dependency versions
├── helix/
│   ├── module.nix         # Flake-parts module
│   ├── default.nix        # Package builder
│   └── config.nix         # Helix settings
├── neovim/
│   ├── module.nix         # Flake-parts module
│   ├── default.nix        # Package builder
│   ├── options.nix        # Core Vim options
│   ├── ui.nix             # UI plugins
│   ├── lsp.nix            # LSP configuration
│   ├── cmp.nix            # Completion
│   ├── git.nix            # Git integration
│   ├── telescope.nix      # Fuzzy finder
│   ├── treesitter.nix     # Syntax highlighting
│   └── ...                # Additional modules
├── zed/
│   ├── module.nix         # Flake-parts module
│   ├── default.nix        # Package builder
│   └── settings.nix       # Zed configuration
├── pi/
│   ├── module.nix         # Flake-parts module
│   ├── home-module.nix    # Home Manager module
│   └── default.nix        # Package builder
└── agent-console/
    ├── module.nix         # Flake-parts module
    ├── flake-module.nix   # Optional configurable module
    ├── default.nix        # Launcher package builder
    └── ...
```

### Separation of concerns

- `pi/` contains only generic Pi packaging/configuration.
- `neovim/` contains only generic Neovim configuration.
- `zellij/` contains only generic Zellij packaging/configuration.
- `agent-console/` contains all Pi↔Neovim↔Zellij integration logic.


## Customization

### Modifying Editor Settings

Each editor has its own configuration file(s):

- **Helix**: Edit `helix/config.nix` (TOML format as Nix attrset)
- **Neovim**: Edit files in `neovim/` directory (nixvim modules)
- **Zed**: Edit `zed/settings.nix` (JSON format as Nix attrset)

After making changes, rebuild:

```bash
nix flake update  # Optional: update dependencies
nix build .#&lt;editor&gt;
```

### Adding New Plugins or Tools

1. Add the configuration to the respective editor's settings file
2. If needed, update `flake.nix` inputs for new dependencies
3. Rebuild the editor package

### Example: Changing Zed Theme

Edit `zed/settings.nix`:

```nix
{
  theme = "Atom One Light";  # Change from "One Dark"
  # ... rest of settings
}
```

### Pi AI Coding Agent

Pi is available as both a standalone package and a Home Manager module.

#### Simple Usage (Standalone)

Run pi directly from devtools:

```bash
nix run github:nithesh/devtools#pi
```

Or with a custom package:

```nix
# In your flake
packages.pi = devtools.packages.${system}.pi.override {
  settings = {
    model = "anthropic/claude-sonnet-4-20250514";
    theme = "default";
    showThinking = true;
  };
  agentsMd = builtins.readFile ./my-agents.md;
};
```

#### Home Manager Module (Declarative)

Add the home-manager module to your configuration:

```nix
# flake.nix
{
  inputs.devtools.url = "github:nithesh/devtools";

  outputs = { self, nixpkgs, home-manager, devtools, ... }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        devtools.homeManagerModules.pi
        {
          programs.pi = {
            enable = true;
            
            settings = {
              model = "anthropic/claude-sonnet-4-20250514";
              theme = "default";
              showThinking = true;
              enableCompaction = true;
            };
            
            agentsMd = '''
              # Global AGENTS.md
              
              You are an expert Nix developer. When working with Nix files:
              - Prefer modern nix (nixpkgs.lib) idioms
              - Use flake-parts for flake structure
              - Follow the existing code style
            ''';
          };
        }
      ];
    };
}
```

#### Pi Configuration Reference

Available settings (see [pi settings docs](https://github.com/badlogic/pi-mono/blob/main/docs/settings.md)):

```nix
programs.pi.settings = {
  # Model
  model = "anthropic/claude-sonnet-4-20250514";
  
  # Providers
  providers = [{
    name = "anthropic";
    apiKey = "sk-ant-...";  # Or use env var ANTHROPIC_API_KEY
  }];
  
  # Terminal/TUI
  theme = "default";
  showThinking = true;
  collapseToolOutput = false;
  
  # Behavior
  steeringMode = "one-at-a-time";  # or "all"
  followUpMode = "one-at-a-time";  # or "all"
  transport = "auto";  # or "sse", "websocket"
  enableCompaction = true;
  
  # Telemetry
  enableInstallTelemetry = true;
};
```

## Usage in Home Manager

To use these tools in your home-manager configuration:

```nix
# In your home-manager flake.nix
{
  inputs.devtools.url = "github:nithesh/devtools";

  outputs = { self, nixpkgs, home-manager, devtools, ... }: {
    homeConfigurations.username = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home.packages = [
            devtools.packages.x86_64-linux.helix
            devtools.packages.x86_64-linux.zed
            devtools.packages.x86_64-linux.neovim
            devtools.packages.x86_64-linux.pi
          ];
        }
      ];
    };
  };
}
```

## Development

### Updating Dependencies

Update all flake inputs:

```bash
nix flake update
```

Update specific input:

```bash
nix flake lock --update-input nixpkgs
```

### Checking Flake

Validate flake structure and run checks:

```bash
nix flake check
```

### Formatting Nix Code

Format all Nix files with alejandra:

```bash
nix fmt
```

## Technical Details

### Architecture

This project uses:
- **[Nix Flakes](https://nixos.wiki/wiki/Flakes)**: Modern Nix package and configuration management
- **[flake-parts](https://flake.parts/)**: Modular flake composition framework
- **[nixvim](https://github.com/nix-community/nixvim)**: Declarative Neovim configuration in Nix
- **[llm-agents.nix](https://github.com/numtide/llm-agents.nix)**: AI coding agent packaging
- **nixpkgs 25.11**: Latest package versions from NixOS

### How It Works

1. Each tool has a `module.nix` that registers it as a flake package
2. `default.nix` builds the tool with custom configuration
3. Configuration files define settings in Nix
4. The main `flake.nix` imports all tool modules
5. Dev shell provides all tools for development

## Contributing

Feel free to customize this for your own use! To add a new tool:

1. Create a new directory `&lt;tool&gt;/`
2. Add `module.nix`, `default.nix`, and configuration files
3. Import the module in `flake.nix`
4. Optional: Add to devShell buildInputs

## License

This is a personal configuration repository. Use and modify as needed for your own setup.

## Resources

- [Nix Documentation](https://nixos.org/manual/nix/stable/)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
- [Helix Documentation](https://docs.helix-editor.com/)
- [Neovim Documentation](https://neovim.io/doc/)
- [Zed Documentation](https://zed.dev/docs)
- [nixvim Documentation](https://nix-community.github.io/nixvim/)
- [Pi Documentation](https://github.com/badlogic/pi-mono)
