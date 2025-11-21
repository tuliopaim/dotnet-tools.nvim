# dotnet-tools.nvim

A Neovim plugin that provides essential .NET development tools, including debugging with launch profiles, test running, user secrets management, and IDE integration.

## Features

- **Smart Debugging**: Launch .NET applications with support for `launchSettings.json` profiles
  - Automatic DLL detection and building
  - Profile selection with environment variables and command-line arguments
  - Integration with [nvim-dap](https://github.com/mfussenegger/nvim-dap)

- **Test Runner**: Run .NET tests directly from Neovim
  - Run individual test methods at cursor
  - Run all tests in current class
  - Supports both tmux and Neovim split windows

- **User Secrets**: Manage .NET user secrets
  - Automatic initialization of UserSecretsId
  - Quick access to secrets.json file

- **IDE Integration**: Open current file in JetBrains Rider
  - Opens at the exact line number
  - Asynchronous execution

## Requirements

### Required

- Neovim >= 0.8.0

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "tuliopaim/dotnet-tools.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-lua/plenary.nvim",
    --"mfussenegger/nvim-dap"
  },
  config = function()
    require("dotnet-tools").setup({
      -- Configuration options (see below)
    })
  end,
}
```

## Configuration

Default configuration:

```lua
require("dotnet-tools").setup({
  -- Path to the Rider script for opening files in JetBrains Rider
  rider_path = "/Applications/Rider.app/Contents/MacOS/rider",

  -- Automatically build the project before debugging if DLL is missing or outdated
  auto_build = true,

  -- Path to launchSettings.json relative to project root
  launch_settings_path = "Properties/launchSettings.json",

  -- Paths to search for compiled DLLs (in order of preference)
  dll_search_paths = { "bin/Debug", "bin/Release" },

  -- Test runner preference: "tmux", "split", or nil (auto-detect)
  test_runner_preference = nil,
})
```

## Commands

The plugin provides the following commands:

- `:DotnetDebug` - Start debugging with launch profile selection
- `:UserSecrets` - Open or create user secrets file
- `:DotnetTest` - Run test method at cursor
- `:DotnetTestClass` - Run all tests in current class
- `:OpenInRider` - Alias for `:DotnetOpenInRider`

## Usage Examples

### Basic Setup with Keymaps

```lua
require("dotnet-tools").setup()

-- Set up keymaps
vim.keymap.set("n", "<leader>dd", "<cmd>DotnetDebug<cr>", { desc = "Start .NET debugging" })
vim.keymap.set("n", "<leader>ds", "<cmd>DotnetSecrets<cr>", { desc = "Open user secrets" })
```

### Debugging Workflow

1. Open a .NET project file (any .cs file in the project)
2. Set breakpoints in nvim-dap (`:lua require('dap').toggle_breakpoint()`)
3. Run `:DotnetDebug`
4. Select a launch profile if `launchSettings.json` exists
5. The plugin will:
   - Find the .csproj file
   - Build the project if needed
   - Launch the debugger with the selected profile's environment variables and arguments

### Running Tests

Position your cursor on a test method and run `:DotnetTest`, or anywhere in a test class and run `:DotnetTestClass`.

The plugin uses tree-sitter to detect the method and class names automatically.

### Managing User Secrets

Run `:DotnetSecrets` from any file in your .NET project. The plugin will:

- Find the .csproj file
- Initialize UserSecretsId if not present
- Create secrets.json if it doesn't exist
- Open the secrets file for editing

## Troubleshooting

### "plenary.nvim is required" error

Install plenary.nvim as a dependency. See Installation section.

### "nvim-dap is required" error

Install nvim-dap to use debugging features. See Installation section.

### "C# tree-sitter parser not found" warning

Install the C# parser: `:TSInstall c_sharp`

### "No .csproj found" error

Make sure you're in a .NET project directory or have a .NET project file open.

### Debugging doesn't work

1. Ensure nvim-dap is properly configured
2. Check that the project builds successfully (`dotnet build`)
3. Verify the DLL path exists in `bin/Debug/netX.Y/`

### Rider doesn't open

1. Check that `rider_path` points to the correct Rider executable
2. On macOS: `/Applications/Rider.app/Contents/MacOS/rider`
3. On Linux: Usually `rider` if in PATH, or `/opt/rider/bin/rider`
4. On Windows: Typically `C:\Program Files\JetBrains\Rider\bin\rider64.exe`

## API

You can also call the plugin functions programmatically:

```lua
local dotnet_tools = require("dotnet-tools")

-- Start debugging
dotnet_tools.start_debugging()

-- Run test at cursor
dotnet_tools.run_test_at_cursor()

-- Run test class
dotnet_tools.run_test_class()

-- Open user secrets
dotnet_tools.open_or_create_secrets_file()

-- Open in Rider
dotnet_tools.open_in_rider()
```

## License

MIT License - see LICENSE file for details
