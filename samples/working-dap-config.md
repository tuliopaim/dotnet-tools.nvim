# Working Dap configuration

```lua
return {
	{
		-- Debug Framework
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
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

			local map = vim.keymap.set

			local opts = { noremap = true, silent = true }

			-- F5 continues execution (or starts debugging if not active)
			map("n", "<F5>", "<Cmd>lua require'dap'.continue()<CR>", opts)

			map("n", "<F6>", "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>", opts)
			map("n", "<F9>", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", opts)
			map("n", "<F10>", "<Cmd>lua require'dap'.step_over()<CR>", opts)
			map("n", "<F11>", "<Cmd>lua require'dap'.step_into()<CR>", opts)
			map("n", "<leader>di", "<Cmd>lua require'dap'.step_into()<CR>", { noremap = true, silent = true, desc = "step into" })
			map("n", "<F8>", "<Cmd>lua require'dap'.step_out()<CR>", opts)
			-- map("n", "<F12>", "<Cmd>lua require'dap'.step_out()<CR>", opts)
			map("n", "<leader>dT", "<Cmd>lua require'dap'.terminate()<CR>", opts)
			map("n", "<leader>dd", "<Cmd>lua require'dap'.disconnect()<CR>", opts)
			map("n", "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>", opts)
			map("n", "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>", opts)
			map(
				"n",
				"<leader>dt",
				"<Cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>",
				{ noremap = true, silent = true, desc = "debug nearest test" }
			)
		end,
		event = "VeryLazy",
	},
	{ "nvim-neotest/nvim-nio" },
	{
		-- UI for debugging
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"mfussenegger/nvim-dap",
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
				-- Set dapui window
				render = {
					max_type_length = 60,
					max_value_lines = 200,
				},
				-- Only one layout: just the "scopes" (variables) list at the bottom
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 1.0 }, -- 100% of this panel is scopes
						},
						size = 15, -- height in lines (adjust to taste)
						position = "bottom", -- "left", "right", "top", "bottom"
					},
				},
			})

			local map = vim.keymap.set

			map("n", "<leader>du", function()
				dapui.toggle()
			end, { noremap = true, silent = true, desc = "Toggle DAP UI" })

			map({ "n", "v" }, "<leader>dw", function()
				require("dapui").eval(nil, { enter = true })
			end, { noremap = true, silent = true, desc = "Add word under cursor to Watches" })

			map({ "n", "v" }, "Q", function()
				require("dapui").eval()
			end, {
				noremap = true,
				silent = true,
				desc = "Hover/eval a single value (opens a tiny window instead of expanding the full object) ",
			})
		end,
	},
	{
		"nvim-neotest/neotest",
		requires = {
			{
				"Issafalcon/neotest-dotnet",
			},
		},
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		conifig = function()
			require("neotest").setup({
				adapters = {
					require("neotest-dotnet"),
				},
			})
		end,
	},
	{
		"Issafalcon/neotest-dotnet",
		lazy = false,
		dependencies = {
			"nvim-neotest/neotest",
		},
	},
}
```
