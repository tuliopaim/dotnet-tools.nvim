local M = {}

-- Check if plenary is available
local has_plenary, Path = pcall(require, "plenary.path")

-- Find the root directory of a .NET project by searching for .csproj files
M.find_project_root_by_csproj = function(start_path)
	if not has_plenary then
		vim.notify(
			"[dotnet-tools] plenary.nvim is required for project detection. Please install it.",
			vim.log.levels.ERROR
		)
		return nil
	end

	local path = Path:new(start_path)

	while true do
		local csproj_files = vim.fn.glob(path:absolute() .. "/*.csproj", false, true)
		if #csproj_files > 0 then
			return path:absolute()
		end

		local parent = path:parent()
		if parent:absolute() == path:absolute() then
			return nil
		end

		path = parent
	end
end

-- Find the solution root by searching for .sln file, .git directory, or workspace root
M.find_solution_root = function(start_path)
	if not has_plenary then
		vim.notify(
			"[dotnet-tools] plenary.nvim is required for solution detection. Please install it.",
			vim.log.levels.ERROR
		)
		return nil
	end

	local path = Path:new(start_path or vim.fn.getcwd())

	-- First, search upward for .sln file
	local search_path = path
	while true do
		local sln_files = vim.fn.glob(search_path:absolute() .. "/*.sln", false, true)
		if #sln_files > 0 then
			return search_path:absolute()
		end

		local parent = search_path:parent()
		if parent:absolute() == search_path:absolute() then
			break
		end
		search_path = parent
	end

	-- Second, search upward for .git directory
	search_path = path
	while true do
		if vim.fn.isdirectory(search_path:absolute() .. "/.git") == 1 then
			return search_path:absolute()
		end

		local parent = search_path:parent()
		if parent:absolute() == search_path:absolute() then
			break
		end
		search_path = parent
	end

	-- Fallback to workspace root or cwd
	return vim.fn.getcwd()
end

-- Find all projects with launch settings starting from root_path
M.find_all_projects_with_launch_settings = function(root_path)
	local config = require("dotnet-tools.config")

	-- Recursively search for all .csproj files
	local csproj_files = vim.fn.globpath(root_path, "**/*.csproj", false, true)

	local projects = {}

	for _, csproj_path in ipairs(csproj_files) do
		local project_dir = vim.fn.fnamemodify(csproj_path, ":h")
		local launch_settings_path = project_dir .. "/" .. config.options.launch_settings_path

		-- Check if launchSettings.json exists
		if vim.fn.filereadable(launch_settings_path) == 1 then
			-- Get project folder name for display
			local project_folder = vim.fn.fnamemodify(project_dir, ":t")

			-- Try to get AssemblyName from .csproj, fallback to folder name
			local assembly_name = M.get_assembly_name_from_csproj(csproj_path)
			local display_name = assembly_name or project_folder

			-- Calculate relative path from root for better display
			local relative_path = vim.fn.fnamemodify(project_dir, ":~:.")

			table.insert(projects, {
				name = display_name,
				csproj_path = csproj_path,
				project_dir = project_dir,
				relative_path = relative_path,
			})
		end
	end

	return projects
end

-- Find the highest version of the netX.Y folder within a given path.
M.get_highest_net_folder = function(bin_debug_path)
	local dirs = vim.fn.glob(bin_debug_path .. "/net*", false, true)

	if type(dirs) == "number" or #dirs == 0 then
		vim.notify(
			"[dotnet-tools] No netX.Y folders found in " .. bin_debug_path .. ". Have you built the project?",
			vim.log.levels.WARN
		)
		return nil
	end

	table.sort(dirs, function(a, b)
		local ver_a = tonumber(a:match("net(%d+)%.%d+"))
		local ver_b = tonumber(b:match("net(%d+)%.%d+"))
		return ver_a > ver_b
	end)

	return dirs[1]
end

-- Extract AssemblyName from .csproj file
M.get_assembly_name_from_csproj = function(csproj_path)
	local file = io.open(csproj_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	-- Match <AssemblyName>VALUE</AssemblyName> with optional whitespace
	local assembly_name = content:match("<AssemblyName>([^<]+)</AssemblyName>")

	if assembly_name then
		-- Trim whitespace
		assembly_name = assembly_name:match("^%s*(.-)%s*$")
	end

	return assembly_name
end

-- Build and return the full path to the .dll file for debugging.
-- @param project_path (optional) The path to the project directory. If not provided, will search from current file.
M.build_dll_path = function(project_path)
	local config = require("dotnet-tools.config")
	local project_root

	-- If project_path is provided, use it; otherwise, find from current file
	if project_path then
		project_root = project_path
	else
		local current_file = vim.api.nvim_buf_get_name(0)
		local current_dir = vim.fn.fnamemodify(current_file, ":p:h")
		project_root = M.find_project_root_by_csproj(current_dir)
	end

	if not project_root then
		vim.notify(
			"[dotnet-tools] Could not find project root (no .csproj found). Are you in a .NET project?",
			vim.log.levels.ERROR
		)
		return nil
	end

	local csproj_files = vim.fn.glob(project_root .. "/*.csproj", false, true)
	if #csproj_files == 0 then
		vim.notify("[dotnet-tools] No .csproj file found in project root: " .. project_root, vim.log.levels.ERROR)
		return nil
	end

	-- Try to get AssemblyName from .csproj file
	local project_name = M.get_assembly_name_from_csproj(csproj_files[1])

	if project_name then
		print("[dotnet-tools] Using AssemblyName from .csproj: " .. project_name)
	else
		-- Fallback to filename if AssemblyName not found
		project_name = vim.fn.fnamemodify(csproj_files[1], ":t:r")
		print("[dotnet-tools] No AssemblyName found, using .csproj filename: " .. project_name)
	end

	-- Try each configured search path
	for _, search_path in ipairs(config.options.dll_search_paths) do
		local bin_path = project_root .. "/" .. search_path
		if vim.fn.isdirectory(bin_path) == 1 then
			local highest_net_folder = M.get_highest_net_folder(bin_path)
			if highest_net_folder then
				local dll_path = highest_net_folder .. "/" .. project_name .. ".dll"
				if vim.fn.filereadable(dll_path) == 1 then
					print("[dotnet-tools] Launching: " .. dll_path)
					return dll_path
				end
			end
		end
	end

	vim.notify(
		"[dotnet-tools] Could not find compiled DLL for " .. project_name .. ". Have you built the project?",
		vim.log.levels.ERROR
	)
	return nil
end

M.get_function_name_with_treesitter = function()
	-- Check if treesitter parser is available
	local has_parser = pcall(vim.treesitter.get_parser, 0, "c_sharp")
	if not has_parser then
		vim.notify(
			"[dotnet-tools] C# tree-sitter parser not found. Install it with :TSInstall c_sharp",
			vim.log.levels.WARN
		)
		return nil
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1] - 1
	local col = cursor[2]
	local parser = vim.treesitter.get_parser(0, "c_sharp")
	if not parser then
		return nil
	end

	local tree = parser:parse()[1]
	local root = tree:root()

	-- Traverse up the tree from the current node until we find a method declaration
	local node = root:named_descendant_for_range(line, col, line, col)
	while node do
		if node:type() == "method_declaration" then
			-- Get the name node
			local name_node = node:field("name")[1]

			if name_node then
				local function_name = vim.treesitter.get_node_text(name_node, 0)
				return function_name
			end
		end
		node = node:parent()
	end

	return nil
end

M.get_class_name = function()
	-- Check if treesitter parser is available
	local has_parser = pcall(vim.treesitter.get_parser, 0, "c_sharp")
	if not has_parser then
		vim.notify(
			"[dotnet-tools] C# tree-sitter parser not found. Install it with :TSInstall c_sharp",
			vim.log.levels.WARN
		)
		return nil
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1] - 1
	local col = cursor[2]
	local parser = vim.treesitter.get_parser()
	if not parser then
		return nil
	end
	local lang_tree = parser:language_for_range({ line, col, line, col })
	for _, tree in ipairs(lang_tree:trees()) do
		local root = tree:root()
		-- Traverse up the tree from the current node until we find a class declaration
		local node = root:named_descendant_for_range(line, col, line, col)
		while node do
			if node:type() == "class_declaration" then
				-- Assuming the class name is a direct child of the class declaration
				for child_node in node:iter_children() do
					if child_node:type() == "identifier" then
						local class_name = vim.treesitter.get_node_text(child_node, 0)
						print("[dotnet-tools] Class name: " .. class_name)
						return class_name
					end
				end
			end
			node = node:parent()
		end
	end

	return nil
end

return M
