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

- **NuGet Package Management**: Search, install, update, and remove NuGet packages
  - Interactive package search with partial name matching
  - Version selection for all packages
  - List currently installed packages
  - Update and remove packages with confirmation

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

  -- NuGet package management settings
  nuget = {
    -- Maximum number of search results to return
    search_limit = 20,

    -- Include prerelease versions when fetching package versions
    include_prerelease = false,
  },
})
```

## Commands

The plugin provides the following commands:

### Debugging and Testing
- `:DotnetDebug` - Start debugging with launch profile selection
- `:DotnetTest` - Run test method at cursor
- `:DotnetTestClass` - Run all tests in current class

### NuGet Package Management
- `:DotnetNugetAdd` - Search and install a NuGet package
- `:DotnetNugetList` - List installed packages and update selected package to a different version
- `:DotnetNugetRemove` - Remove a NuGet package from the project

### Other Tools
- `:UserSecrets` - Open or create user secrets file
- `:OpenInRider` - Open the current project/file in Rider

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

Run `:UserSecrets` from any file in your .NET project. The plugin will:

- Find the .csproj file
- Initialize UserSecretsId if not present
- Create secrets.json if it doesn't exist
- Open the secrets file for editing

### Managing NuGet Packages

**Adding a package:**
1. Run `:DotnetNugetAdd`
2. Type a partial package name (e.g., "Newtonsoft")
3. Select the desired package from search results
4. Choose a version to install

**Listing and updating packages:**
1. Run `:DotnetNugetList` to see all installed packages
2. Select the package to update
3. Choose the new version from available versions

**Removing a package:**
1. Run `:DotnetNugetRemove`
2. Select the package to remove
3. Confirm removal

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

-- NuGet package management
dotnet_tools.nuget_search_and_install()
dotnet_tools.nuget_list_packages()
dotnet_tools.nuget_remove_package()
```

## Examples

### Working Dap configuration

```lua
return {
	{
		-- Debug Framework
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
		},
		keys = {
			{ "<F5>", "<Cmd>lua require'dap'.continue()<CR>", desc = "Continue debugging" },
			{ "<F9>", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", desc = "Toggle breakpoint" },
			{ "<F10>", "<Cmd>lua require'dap'.step_over()<CR>", desc = "Step over" },
			{ "<F11>", "<Cmd>lua require'dap'.step_into()<CR>", desc = "Step into" },
			{ "<F8>", "<Cmd>lua require'dap'.step_out()<CR>", desc = "Step out" },
			{ "<leader>di", "<Cmd>lua require'dap'.step_into()<CR>", desc = "Step into" },
			{ "<leader>dT", "<Cmd>lua require'dap'.terminate()<CR>", desc = "Terminate" },
			{ "<leader>dD", "<Cmd>lua require'dap'.disconnect()<CR>", desc = "Disconnect" },
			{ "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>", desc = "Open REPL" },
			{ "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>", desc = "Run last" },
		},
		config = function()
			local dap = require("dap")

			local netcoredbg_adapter = {
				type = "executable",
				command = "netcoredbg",
				args = { "--interpreter=vscode" },
			}

			dap.adapters.netcoredbg = netcoredbg_adapter -- needed for normal debugging
			dap.adapters.coreclr = netcoredbg_adapter -- needed for unit test debugging

			-- Simplified configuration - actual config is built by dotnet-tools.dap
			dap.configurations.cs = {}
		end,
	},
	{
		-- UI for debugging
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"mfussenegger/nvim-dap",
			"nvim-neotest/nvim-nio",
		},
		keys = {
			{ "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
			{ "<leader>dw", function() require("dapui").eval(nil, { enter = true }) end, mode = { "n", "v" }, desc = "Add to watches" },
			{ "Q", function() require("dapui").eval() end, mode = { "n", "v" }, desc = "Hover eval" },
		},
		config = function()
			local dapui = require("dapui")
			local dap = require("dap")

			--- open ui immediately when debugging starts
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			vim.fn.sign_define("DapBreakpoint", {
				text = "●",
				texthl = "DapBreakpointSymbol",
				linehl = "DapBreakpoint",
				numhl = "DapBreakpoint",
			})

			vim.fn.sign_define("DapStopped", {
				text = "→",
				texthl = "yellow",
				linehl = "DapBreakpoint",
				numhl = "DapBreakpoint",
			})

			vim.fn.sign_define("DapBreakpointRejected", {
				text = "⭕",
				texthl = "DapStoppedSymbol",
				linehl = "DapBreakpoint",
				numhl = "DapBreakpoint",
			})

			-- more minimal ui
			dapui.setup({
				expand_lines = true,
				controls = { enabled = false }, -- no extra play/step buttons
				floating = { border = "rounded" },
				render = {
					max_type_length = 60,
					max_value_lines = 200,
				},
				layouts = {
					{
						elements = {
							{ id = "repl", size = 1.0 },
						},
						size = 15,
						position = "bottom",
					},
					{
						elements = {
							{ id = "scopes", size = 1.0 },
						},
						size = 70,
						position = "right",
					},
				},
			})
		end,
	},
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"Issafalcon/neotest-dotnet",
		},
		-- Only load when actually running tests
		keys = {
			{ "<F6>", "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>", desc = "Debug nearest test" },
			{ "<leader>dt", "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>", desc = "Debug nearest test" },
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-dotnet"),
				},
			})
		end,
	},
}
```

### Working dotnet-tools config

```lua
return {
	{
		"dotnet-tools.nvim",
		dir = "~/dev/personal/dotnet-tools.nvim",
		dependencies = {
			"mfussenegger/nvim-dap",
			"nvim-treesitter/nvim-treesitter",
			"nvim-lua/plenary.nvim",
		},
		ft = "cs", -- Only load for C# files
		keys = {
			{
				"<leader>rt",
				":DotnetTest<CR>",
				desc = "Run test at cursor",
			},
			{
				"<leader>rc",
				":DotnetTestClass<CR>",
				desc = "Run test class",
			},
			{
				"<leader>dd",
				":DotnetDebug<CR>",
				desc = "Start .NET debugging",
			},
			{
				"<leader>ds",
				":UserSecrets<CR>",
				desc = "Open user secrets",
			},
			{
				"<leader>dr",
				":OpenInRider<CR>",
				desc = "Open in Rider",
			},
			{
				"<leader>na",
				":DotnetNugetAdd<CR>",
				desc = "Add NuGet package",
			},
			{
				"<leader>nl",
				":DotnetNugetList<CR>",
				desc = "List NuGet packages",
			},
			{
				"<leader>nu",
				":DotnetNugetUpdate<CR>",
				desc = "Update NuGet package",
			},
			{
				"<leader>nr",
				":DotnetNugetRemove<CR>",
				desc = "Remove NuGet package",
			},
		},
		config = function()
			require("dotnet-tools").setup({
				rider_path = "/Applications/Rider.app/Contents/MacOS/rider",
                flat_profiles = true,
			})
		end,
	}
}
```

## License

MIT License - see LICENSE file for details
