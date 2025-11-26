# Nithesh's Development Tools

A Nix Flake-based collection of pre-configured editor setups for modern software development. This project provides declarative, reproducible editor configurations using Nix, making it easy to maintain consistent development environments across machines.

## Features

- **Declarative Configuration**: All editor settings defined as Nix expressions
- **Reproducible Builds**: Consistent editor setup across different systems
- **Modular Architecture**: Clean separation of editor configurations
- **LSP Support**: Built-in language server support for Nix and other languages
- **Auto-formatting**: Integrated formatters (alejandra for Nix)

## Available Editors

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
- `nil` - Nix language server
- `alejandra` - Nix formatter

### Building Individual Editors

Build a specific editor package:

```bash
# Build Helix
nix build .#helix

# Build Neovim
nix build .#neovim

# Build Zed
nix build .#zed
```

Run the built editor:

```bash
./result/bin/hx      # Helix
./result/bin/nvim    # Neovim
./result/bin/zed     # Zed
```

### Running Directly

Run an editor without building:

```bash
nix run .#helix
nix run .#neovim
nix run .#zed
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
└── zed/
    ├── module.nix         # Flake-parts module
    ├── default.nix        # Package builder
    └── settings.nix       # Zed configuration
```

## Customization

### Modifying Editor Settings

Each editor has its own configuration file(s):

- **Helix**: Edit `helix/config.nix` (TOML format as Nix attrset)
- **Neovim**: Edit files in `neovim/` directory (nixvim modules)
- **Zed**: Edit `zed/settings.nix` (JSON format as Nix attrset)

After making changes, rebuild:

```bash
nix flake update  # Optional: update dependencies
nix build .#<editor>
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
- **nixpkgs-unstable**: Latest package versions from NixOS

### How It Works

1. Each editor has a `module.nix` that registers it as a flake package
2. `default.nix` builds the editor with custom configuration
3. Configuration files define editor settings in Nix
4. The main `flake.nix` imports all editor modules
5. Dev shell provides all tools for development

## Contributing

Feel free to customize this for your own use! To add a new editor:

1. Create a new directory `<editor>/`
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
