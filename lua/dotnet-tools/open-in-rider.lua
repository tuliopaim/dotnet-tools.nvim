local M = {}

M.open_in_rider = function()
	local config = require("dotnet-tools.config")
	local script_path = config.options.rider_path

	local path = vim.fn.expand("%:p")
	if path == "" then
		vim.notify("[dotnet-tools] No file is currently open", vim.log.levels.WARN)
		return
	end

	local line = vim.fn.line(".")
	local cmd = string.format("%s --line %d %s", script_path, line, path)

	vim.notify("[dotnet-tools] Opening in Rider: " .. path .. ":" .. line, vim.log.levels.INFO)

	-- Run the command asynchronously in the background
	local job_id = vim.fn.jobstart(cmd, {
		on_exit = function(_, code, _)
			if code ~= 0 then
				vim.notify("[dotnet-tools] Rider command failed with exit code " .. code, vim.log.levels.ERROR)
			end
		end,
	})

	-- Check if the job was started successfully
	if job_id <= 0 then
		vim.notify(
			"[dotnet-tools] Failed to start Rider. Check that rider_path is correct: " .. script_path,
			vim.log.levels.ERROR
		)
	end
end

return M
