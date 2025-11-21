# Working dotnet-tools config

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
		event = "VeryLazy",
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
		},
		config = function()
			require("dotnet-tools").setup({
				rider_path = "/Applications/Rider.app/Contents/MacOS/rider",
			})
		end,
	}
}
```

