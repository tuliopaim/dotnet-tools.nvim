local config = require("dotnet-tools.config")
local secrets = require("dotnet-tools.secrets")
local open_in_rider = require("dotnet-tools.open-in-rider")
local tests = require("dotnet-tools.tests")
local debug = require("dotnet-tools.debug")

local M = {}

-- Export public API functions
M.open_or_create_secrets_file = secrets.open_or_create_secrets_file
M.open_in_rider = open_in_rider.open_in_rider
M.run_test_at_cursor = tests.run_test_at_cursor
M.run_test_class = tests.run_test_class
M.start_debugging = debug.start_debugging

function M.setup(opts)
	-- Setup configuration
	config.setup(opts)

	-- Create user commands with new standardized names
	vim.api.nvim_create_user_command("DotnetDebug", debug.start_debugging, {})
	vim.api.nvim_create_user_command("UserSecrets", secrets.open_or_create_secrets_file, {})
	vim.api.nvim_create_user_command("OpenInRider", function()
		open_in_rider.open_in_rider()
	end, {})
	vim.api.nvim_create_user_command("DotnetTest", tests.run_test_at_cursor, {})
	vim.api.nvim_create_user_command("DotnetTestClass", tests.run_test_class, {})
end

return M
