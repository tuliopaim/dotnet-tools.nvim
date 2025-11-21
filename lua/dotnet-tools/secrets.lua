local function find_user_secrets_id(path)
	local files = vim.fn.glob(path .. "*.csproj", false, true)

	for _, file in ipairs(files) do
		local f = io.open(file, "r")
		if f then
			local content = f:read("*all")
			f:close()
			for secrets_id in string.gmatch(content, "<UserSecretsId>(.-)</UserSecretsId>") do
				return secrets_id
			end
		end
	end

	return nil
end

local M = {}

M.open_or_create_secrets_file = function()
	local current_dir = vim.fn.expand("%:p:h") .. "/"

	-- Check if we're in a .NET project directory
	local csproj_files = vim.fn.glob(current_dir .. "*.csproj", false, true)
	if #csproj_files == 0 then
		vim.notify(
			"[dotnet-tools] No .csproj file found in current directory. Are you in a .NET project?",
			vim.log.levels.ERROR
		)
		return
	end

	local secrets_id = find_user_secrets_id(current_dir)
	local dotnet_user_secrets_cmd = "dotnet user-secrets -p " .. current_dir

	if not secrets_id then
		vim.notify("[dotnet-tools] No UserSecretsId found, initializing user secrets...", vim.log.levels.INFO)
		local init_result = vim.fn.system(dotnet_user_secrets_cmd .. " init")

		if vim.v.shell_error ~= 0 then
			vim.notify("[dotnet-tools] Failed to initialize user secrets:\n" .. init_result, vim.log.levels.ERROR)
			return
		end

		secrets_id = find_user_secrets_id(current_dir)
		if secrets_id then
			vim.notify("[dotnet-tools] User secrets initialized: " .. secrets_id, vim.log.levels.INFO)
		end
	end

	if not secrets_id then
		vim.notify("[dotnet-tools] Failed to create UserSecretsId", vim.log.levels.ERROR)
		return
	end

	local file_path = vim.fn.expand("$HOME") .. "/.microsoft/usersecrets/" .. secrets_id .. "/secrets.json"

	if vim.fn.filereadable(file_path) == 1 then
		vim.notify("[dotnet-tools] Opening secrets.json", vim.log.levels.INFO)
		vim.cmd("edit " .. file_path)
		return
	end

	vim.notify("[dotnet-tools] secrets.json not found, creating with default values...", vim.log.levels.INFO)

	local set_result = vim.fn.system(dotnet_user_secrets_cmd .. ' set "foo" "bar"')

	if vim.v.shell_error ~= 0 then
		vim.notify("[dotnet-tools] Failed to create secrets.json:\n" .. set_result, vim.log.levels.ERROR)
		return
	end

	if vim.fn.filereadable(file_path) == 1 then
		vim.cmd("edit " .. file_path)
		return
	end

	vim.notify("[dotnet-tools] Failed to create secrets.json file", vim.log.levels.ERROR)
end

return M
