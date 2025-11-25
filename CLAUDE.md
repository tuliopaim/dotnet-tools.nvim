# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin written in Lua that provides .NET development tools including debugging with launch profiles, test running, user secrets management, and IDE integration. The plugin is designed to work with .NET 6.0+ projects and integrates with nvim-dap for debugging and nvim-treesitter for C# code parsing.

## Architecture

### Module Structure

The plugin follows a modular architecture with each feature in its own file:

- **`lua/dotnet-tools/init.lua`**: Main entry point that exposes public API and creates user commands
- **`lua/dotnet-tools/config.lua`**: Configuration management with defaults
- **`lua/dotnet-tools/helpers.lua`**: Shared utilities for project detection, DLL path resolution, and treesitter parsing
- **`lua/dotnet-tools/debug.lua`**: Debugging functionality with launch profile support
- **`lua/dotnet-tools/tests.lua`**: Test runner that supports both tmux and Neovim splits
- **`lua/dotnet-tools/secrets.lua`**: User secrets management
- **`lua/dotnet-tools/open-in-rider.lua`**: JetBrains Rider integration

### Key Architectural Patterns

**Project Root Detection**: The plugin uses plenary.nvim to traverse up the directory tree from the current file to find the nearest `.csproj` file. This is the foundation for all project-relative operations (`helpers.find_project_root_by_csproj`).

**DLL Path Resolution**: The debugging system searches for compiled DLLs by:
1. Finding the project root via `.csproj` file
2. Extracting `<AssemblyName>` from the `.csproj` (with fallback to `.csproj` filename)
3. Searching configured paths (`bin/Debug`, `bin/Release`) for the highest `netX.Y` folder
4. Constructing the DLL path as `{highest_net_folder}/{assembly_name}.dll`

This logic is in `helpers.build_dll_path()` and `helpers.get_highest_net_folder()`.

**Launch Profile Handling**: The debug module (`debug.lua`) reads `Properties/launchSettings.json`, filters for profiles with `commandName: "Project"`, and presents them to the user via `vim.ui.select`. The selected profile's environment variables and command-line arguments are passed to nvim-dap.

**Treesitter-Based Test Detection**: Test running relies on treesitter to extract method and class names from C# code. The plugin walks up the AST from the cursor position to find `method_declaration` and `class_declaration` nodes (`helpers.get_function_name_with_treesitter()` and `helpers.get_class_name()`).

## Development Commands

Since this is a Neovim plugin without traditional build/test infrastructure, development primarily involves:

**Testing the plugin**: Open Neovim in this directory with the plugin loaded, then test commands manually:
```bash
nvim --cmd "set runtimepath+=." lua/dotnet-tools/init.lua
```

**Linting (if you add it)**: Currently no linter is configured. Consider adding stylua for Lua formatting:
```bash
stylua lua/
```

**Manual testing with a .NET project**: The plugin is designed to be tested in a real .NET project. Create or use an existing .NET project and load the plugin locally.

## Critical Implementation Details

**AssemblyName Priority**: When resolving DLL paths, always check `<AssemblyName>` in the `.csproj` file first before falling back to the `.csproj` filename. This was recently fixed in commit `3fcbbd6`.

**Async Profile Selection**: The debugging flow uses `vim.ui.select` for profile selection, which is asynchronous. The `configure_debug_session` function uses a callback pattern to handle this (`debug.lua:141-208`).

**User Commands**: The plugin creates the following user commands: `:DotnetDebug`, `:DotnetTest`, `:DotnetTestClass`, `:UserSecrets`, and `:OpenInRider`.

**Dependency Handling**: All dependencies are optional and checked at runtime using `pcall`. The plugin will not break during setup if dependencies are missing - errors only appear when users try to use features that require unavailable dependencies:
- nvim-dap: Checked in `debug.lua:212` with `pcall(require, "dap")` when `:DotnetDebug` is run
- treesitter: Checked in `helpers.lua:131` and `helpers.lua:171` when test detection is needed
- plenary.nvim: Checked in `helpers.lua:4` when project root detection is needed
- tmux: Checked via environment variable, falls back to Neovim splits if not available
- jq: Used to sanitize `launchSettings.json`. If `jq` is not available, the plugin will fall back to the default JSON parser. It is recommended to have `jq` installed to avoid issues with hidden characters in `launchSettings.json`.

This design allows users to install only the dependencies they need for the features they use. The plugin loads successfully at startup regardless of which dependencies are present.

## Code Patterns to Follow

**Error Handling**: Always use `vim.notify` with appropriate log levels (`vim.log.levels.ERROR`, `vim.log.levels.WARN`, `vim.log.levels.INFO`) and prefix messages with `[dotnet-tools]`.

**Configuration Access**: Always access config via `require("dotnet-tools.config").options` rather than storing local references, as the config may be updated by the user.

**Project Context**: Most operations need project root context. Use `helpers.find_project_root_by_csproj()` to locate the project before performing operations.

**Command Registration**: Register new commands in `init.lua` using `vim.api.nvim_create_user_command`. Export corresponding functions in the module's public API.

**Optional Dependencies Pattern**: When adding new features that depend on external plugins, always use `pcall(require, "plugin-name")` at runtime (when the feature is invoked) rather than at module load time. This ensures the plugin loads successfully even if optional dependencies are missing. Check the pattern in `debug.lua:212` for reference.
