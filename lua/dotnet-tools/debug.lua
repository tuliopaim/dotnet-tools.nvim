local helpers = require("dotnet-tools.helpers")
local M = {}

-- Helper function to find project root by searching for .csproj file
local function find_project_root()
	-- First try: find .csproj in current file's directory tree
	local current_file = vim.fn.expand("%:p")
	if current_file ~= "" then
		local current_dir = vim.fn.fnamemodify(current_file, ":h")
		local project_root = helpers.find_project_root_by_csproj(current_dir)
		if project_root then
			return project_root
		end
	end

	-- Second try: search cwd for .csproj files
	local cwd_root = helpers.find_project_root_by_csproj(vim.fn.getcwd())
	if cwd_root then
		return cwd_root
	end

	return vim.fn.getcwd()
end

-- Helper function to read and parse launchSettings.json
local function read_launch_settings(project_path)
	local config = require("dotnet-tools.config")
	local launch_settings_path = project_path .. "/" .. config.options.launch_settings_path

	local file = io.open(launch_settings_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	if vim.fn.executable("jq") == 1 then
		local sanitized_content = vim.fn.system("jq .", content)
		if vim.v.shell_error == 0 then
			content = sanitized_content
		else
			vim.notify("[dotnet-tools] Failed to sanitize launchSettings.json with jq.", vim.log.levels.WARN)
		end
	end

	local ok, launch_settings = pcall(vim.json.decode, content)
	if not ok then
		vim.notify("[dotnet-tools] Failed to parse launchSettings.json", vim.log.levels.WARN)
		return nil
	end

	return launch_settings
end

-- Helper to get profile data (name and profile object)
local function get_launch_profile_data(project_path, launch_settings)
	if not launch_settings or not launch_settings.profiles then
		return nil
	end

	-- Get all "Project" profiles
	local profile_names = {}
	local profiles_map = {}
	for name, profile in pairs(launch_settings.profiles) do
		if profile.commandName == "Project" then
			table.insert(profile_names, name)
			profiles_map[name] = profile
		end
	end

	if #profile_names == 0 then
		return nil
	end

	return {
		names = profile_names,
		map = profiles_map,
	}
end

-- Check if DLL exists and optionally prompt to build
local function check_and_build_dll(project_path)
	local config = require("dotnet-tools.config")
	local dll = helpers.build_dll_path(project_path)

	if dll and dll ~= "" and vim.fn.filereadable(dll) == 1 then
		return dll
	end

	-- DLL missing or not found
	if not config.options.auto_build then
		vim.notify(
			"[dotnet-tools] DLL not found and auto_build is disabled. Build your project first.",
			vim.log.levels.ERROR
		)
		return nil
	end

	-- Prompt to build
	local choice = vim.fn.confirm("DLL not found. Build the project?", "&Yes\n&No", 1)

	if choice ~= 1 then
		return nil
	end

	-- Build the project
	local project_name = vim.fn.fnamemodify(project_path, ":t")
	local csproj_files = vim.fn.globpath(project_path, "*.csproj", false, true)

	if #csproj_files == 0 then
		vim.notify("[dotnet-tools] No .csproj file found in " .. project_path, vim.log.levels.ERROR)
		return nil
	end

	vim.notify("[dotnet-tools] Building " .. project_name .. "...", vim.log.levels.INFO)
	local build_cmd = "dotnet build " .. vim.fn.shellescape(csproj_files[1])
	local build_result = vim.fn.system(build_cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("[dotnet-tools] Build failed:\n" .. build_result, vim.log.levels.ERROR)
		return nil
	end

	vim.notify("[dotnet-tools] Build succeeded!", vim.log.levels.INFO)

	-- Try to get DLL path again after build
	dll = helpers.build_dll_path(project_path)
	if not dll or dll == "" then
		vim.notify("[dotnet-tools] Failed to find DLL even after build", vim.log.levels.ERROR)
		return nil
	end

	return dll
end

-- Prompt user to select a startup project (async with callback)
local function select_project(projects, callback)
	-- Format project names with relative paths for display
	local display_names = {}
	for _, project in ipairs(projects) do
		table.insert(display_names, project.name .. " (" .. project.relative_path .. ")")
	end

	vim.ui.select(display_names, {
		prompt = "Select startup project:",
	}, function(choice, idx)
		if choice and idx then
			callback(projects[idx])
		else
			callback(nil)
		end
	end)
end

-- Prompt user to select a launch profile (async with callback)
local function select_launch_profile(profile_data, callback)
	vim.ui.select(profile_data.names, {
		prompt = "Select launch profile:",
	}, function(choice)
		if choice then
			callback(profile_data.map[choice])
		else
			callback(nil)
		end
	end)
end

local function configure_debug_session(callback)
	-- Find solution root (searches for .sln, .git, or uses cwd)
	local current_file = vim.fn.expand("%:p")
	local start_dir = current_file ~= "" and vim.fn.fnamemodify(current_file, ":h") or vim.fn.getcwd()
	local solution_root = helpers.find_solution_root(start_dir)

	if not solution_root then
		vim.notify("[dotnet-tools] Could not find solution root", vim.log.levels.ERROR)
		callback(nil)
		return
	end

	-- Find all projects with launch settings
	local projects = helpers.find_all_projects_with_launch_settings(solution_root)

	if #projects == 0 then
		vim.notify(
			"[dotnet-tools] No projects with launchSettings.json found in solution. Create a launch profile first.",
			vim.log.levels.ERROR
		)
		callback(nil)
		return
	end

	-- Function to continue with profile selection for a given project
	local function continue_with_project(selected_project)
		local project_path = selected_project.project_dir

		-- Check/build DLL for selected project
		local dll = check_and_build_dll(project_path)
		if not dll then
			vim.notify("[dotnet-tools] Cannot start debugging without DLL", vim.log.levels.ERROR)
			callback(nil)
			return
		end

		-- Read launch settings for selected project
		local launch_settings = read_launch_settings(project_path)
		if not launch_settings then
			-- No launchSettings.json (shouldn't happen since we filtered), return basic config
			callback({
				type = "coreclr",
				name = "Launch .NET App",
				request = "launch",
				program = dll,
				cwd = project_path,
				env = {},
				args = {},
			})
			return
		end

		-- Get profile data
		local profile_data = get_launch_profile_data(project_path, launch_settings)
		if not profile_data then
			vim.notify("[dotnet-tools] No Project profiles found in launchSettings.json", vim.log.levels.WARN)
			callback({
				type = "coreclr",
				name = "Launch .NET App",
				request = "launch",
				program = dll,
				cwd = project_path,
				env = {},
				args = {},
			})
			return
		end

		-- Prompt user to select profile (async)
		select_launch_profile(profile_data, function(selected_profile)
			if not selected_profile then
				vim.notify("[dotnet-tools] No profile selected, aborting debug session", vim.log.levels.WARN)
				callback(nil)
				return
			end

			-- Build final configuration
			local env_vars = selected_profile.environmentVariables or {}

			-- Add applicationUrl as ASPNETCORE_URLS if present
			if selected_profile.applicationUrl then
				env_vars.ASPNETCORE_URLS = selected_profile.applicationUrl
			end

			local args_str = selected_profile.commandLineArgs or ""
			local args = args_str ~= "" and vim.split(args_str, " ") or {}

			callback({
				type = "coreclr",
				name = "Launch .NET App (" .. selected_project.name .. ")",
				request = "launch",
				program = dll,
				cwd = project_path,
				env = env_vars,
				args = args,
			})
		end)
	end

	-- If only one project, skip project selection
	if #projects == 1 then
		continue_with_project(projects[1])
		return
	end

	-- Multiple projects: prompt user to select startup project (async)
	select_project(projects, function(selected_project)
		if not selected_project then
			vim.notify("[dotnet-tools] No project selected, aborting debug session", vim.log.levels.WARN)
			callback(nil)
			return
		end

		continue_with_project(selected_project)
	end)
end

function M.start_debugging()
	-- Check if nvim-dap is available
	local has_dap, dap = pcall(require, "dap")
	if not has_dap then
		vim.notify(
			"[dotnet-tools] nvim-dap is required for debugging. Please install it.",
			vim.log.levels.ERROR
		)
		return
	end

	configure_debug_session(function(config)
		if not config then
			-- User cancelled or configuration failed
			return
		end

		dap.run(config)
	end)
end

return M
