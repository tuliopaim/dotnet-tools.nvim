local helpers = require("dotnet-tools.helpers")

local run_test_and_print = function(testCmd)
	local config = require("dotnet-tools.config")

	-- Check if in a tmux session
	local tmux_session = os.getenv("TMUX")

	-- Use configured preference if set, otherwise auto-detect
	local use_tmux = tmux_session ~= nil
	if config.options.test_runner_preference == "split" then
		use_tmux = false
	elseif config.options.test_runner_preference == "tmux" then
		if not tmux_session then
			vim.notify(
				"[dotnet-tools] tmux is configured but not detected. Falling back to Neovim split.",
				vim.log.levels.WARN
			)
			use_tmux = false
		end
	end

	if use_tmux then
		-- In a tmux session, open a new tmux pane at the bottom and run the command
		os.execute('tmux split-window -v "sh -c \'' .. testCmd .. "; exec zsh'\"")
	else
		-- Not in a tmux session, open a new split window in Neovim
		vim.cmd("botright split")
		vim.cmd("terminal " .. testCmd)
		vim.cmd("startinsert!")
	end
end

local M = {}

M.run_test_at_cursor = function()
	local class_name = helpers.get_class_name()
	local test_name = helpers.get_function_name_with_treesitter()

	if not test_name then
		vim.notify("[dotnet-tools] No test method found at cursor", vim.log.levels.WARN)
		return
	end

	if not class_name then
		vim.notify("[dotnet-tools] No class name found", vim.log.levels.WARN)
		return
	end

	local cmd = string.format('dotnet test --filter "%s.%s"', class_name, test_name)

	run_test_and_print(cmd)
end

M.run_test_class = function()
	local class_name = helpers.get_class_name()

	if not class_name then
		vim.notify("[dotnet-tools] No class name found", vim.log.levels.WARN)
		return
	end

	local cmd = string.format("dotnet test --filter FullyQualifiedName~%s", class_name)

	run_test_and_print(cmd)
end

return M
