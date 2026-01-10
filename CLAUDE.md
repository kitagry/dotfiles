# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing configuration files for a development environment. The repository manages shell configurations, editor settings, and development tools through symlinks and installation scripts.

## Key Commands

### Installation and Setup
- `./install.sh` - Primary installation script that uses mise for tool management and creates symlinks
- `./install_mac.sh` - macOS-specific installation using Homebrew
- `./download_file.sh` - Downloads additional completion files

### Tool Management
- `mise install <tool>@latest` - Install development tools (go, ghq, deno, fzf, gh, neovim, node, rust, tmux)
- `mise use -g <tool>@latest` - Set global version of a tool
- `mise list` - List installed tools and versions

### Shell Management
- `sheldon source` - Generate shell plugin configuration
- `sheldon add <plugin>` - Add new zsh plugin
- `sheldon edit` - Edit plugin configuration

## Architecture and Structure

### Core Components

**Configuration Management**: The repository uses a symlink-based approach where dotfiles are linked from the repo to home directory locations. Three main categories:
- Direct dotfiles (`.zshrc`, `.vimrc`, `.tmux.conf`, etc.) linked to `$HOME`
- Directory structures (`.config`, `.vim`, `.zsh`) with recursive file linking
- Selective exclusions for git and system files

**Tool Chain**: 
- **mise**: Primary tool version manager replacing asdf/homebrew for development tools
- **sheldon**: Zsh plugin manager written in Rust for fast shell startup
- **Neovim**: Primary editor with Lua-based configuration using custom lazy loading

**Shell Environment**:
- Zsh with extensive plugin system via sheldon
- Pure prompt theme with async capabilities
- Auto-suggestions and syntax highlighting
- Custom completion system with git enhancements

### Configuration Hierarchy

```
.
├── install.sh              # Main setup script
├── install_mac.sh           # macOS variant
├── download_file.sh         # Completion downloads
├── .zshrc                   # Shell configuration
├── .vimrc                   # Vim configuration (legacy)
├── .config/
│   ├── nvim/               # Neovim Lua configuration
│   │   ├── init.lua        # Main config entry point
│   │   └── lua/            # Lua modules
│   ├── sheldon/            # Shell plugin management
│   │   └── plugins.toml    # Plugin definitions
│   ├── alacritty/          # Terminal emulator config
│   ├── git/                # Git configuration
│   └── zeno/               # Zsh abbreviation engine
├── .vim/                   # Vim plugin directory
└── .zsh/                   # Zsh completions and functions
```

### Key Patterns

**Installation Flow**: 
1. Install mise if not present
2. Install development tools through mise
3. Download external completion files
4. Create symlinks for dotfiles and directory structures
5. Handle special cases for multi-level directories

**Editor Configuration**: 
- Neovim uses a custom lazy loading system (`kitagry.lazy`)
- Configuration is modularized through Lua requires
- Local configuration override via `init.local.vim`
- UTF-8 encoding with Japanese language support

**Shell Initialization**:
- mise activation for tool management
- sheldon for plugin loading and management
- XDG Base Directory specification compliance
- Local override support via `.zshrc.local`

## Development Workflow

When modifying configurations:
1. Edit files in the repository directory
2. Run `./install.sh` to update symlinks (if needed)
3. Restart shell or source configurations to test changes
4. For Neovim changes, restart editor or use `:source %`

The repository is designed for cross-platform use but optimized for Unix-like systems with special handling for macOS via Homebrew integration.