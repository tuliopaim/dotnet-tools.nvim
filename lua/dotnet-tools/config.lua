local M = {}

M.defaults = {
	-- Path to the Rider script for opening files in JetBrains Rider
	rider_path = "/Applications/Rider.app/Contents/MacOS/rider",

	-- Automatically build the project before debugging if DLL is missing or outdated
	auto_build = true,

	-- Path to launchSettings.json relative to project root
	launch_settings_path = "Properties/launchSettings.json",

	-- Paths to search for compiled DLLs (in order of preference)
	dll_search_paths = { "bin/Debug", "bin/Release" },

	-- Test runner preference: "tmux" or "split"
	test_runner_preference = nil, -- nil = auto-detect
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

-- Initialize with defaults
M.setup()

return M
