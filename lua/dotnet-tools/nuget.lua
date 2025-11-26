local helpers = require("dotnet-tools.helpers")
local M = {}

-- Helper function to check if dotnet CLI is available
local function check_dotnet_available()
	local result = vim.fn.system("dotnet --version")
	if vim.v.shell_error ~= 0 then
		vim.notify("[dotnet-tools] dotnet CLI not found. Please install .NET SDK.", vim.log.levels.ERROR)
		return false
	end
	return true
end

-- Helper function to search NuGet packages
local function search_nuget(query, callback)
	if not query or query == "" then
		vim.notify("[dotnet-tools] Search query cannot be empty", vim.log.levels.WARN)
		callback(nil)
		return
	end

	local config = require("dotnet-tools.config").options
	local limit = config.nuget.search_limit or 20

	vim.notify("[dotnet-tools] Searching for packages...", vim.log.levels.INFO)

	-- Use dotnet package search command
	local cmd = string.format("dotnet package search %s --take %d --format json", vim.fn.shellescape(query), limit)

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data, _)
			if not data or #data == 0 then
				vim.notify("[dotnet-tools] No data received from search", vim.log.levels.WARN)
				callback(nil)
				return
			end

			-- Join all lines into a single JSON string
			local json_str = table.concat(data, "\n")
			if json_str == "" or json_str == "\n" then
				vim.notify("[dotnet-tools] Empty JSON response", vim.log.levels.WARN)
				callback(nil)
				return
			end

			-- Parse JSON output
			local ok, results = pcall(vim.fn.json_decode, json_str)
			if not ok then
				vim.notify("[dotnet-tools] Failed to parse JSON: " .. tostring(results), vim.log.levels.ERROR)
				callback(nil)
				return
			end

			-- Check structure: searchResult[0].packages
			if not results or not results.searchResult or #results.searchResult == 0 then
				vim.notify("[dotnet-tools] No search results in response", vim.log.levels.WARN)
				callback(nil)
				return
			end

			local first_source = results.searchResult[1]
			if not first_source or not first_source.packages or #first_source.packages == 0 then
				vim.notify("[dotnet-tools] No packages found matching '" .. query .. "'", vim.log.levels.WARN)
				callback(nil)
				return
			end

			-- Extract package information
			local packages = {}
			local package_map = {}

			for _, pkg in ipairs(first_source.packages) do
				local display_name = string.format("%s (%s)", pkg.id, pkg.latestVersion)
				table.insert(packages, display_name)
				package_map[display_name] = {
					id = pkg.id,
					version = pkg.latestVersion,
				}
			end

			vim.notify(
				string.format("[dotnet-tools] Found %d packages", #packages),
				vim.log.levels.INFO
			)
			callback({ packages = packages, map = package_map })
		end,
		on_stderr = function(_, data, _)
			if data and #data > 0 then
				local err = table.concat(data, "\n")
				if err and err ~= "" and err ~= "\n" then
					vim.notify("[dotnet-tools] Search error: " .. err, vim.log.levels.ERROR)
				end
			end
		end,
		on_exit = function(_, code, _)
			if code ~= 0 then
				vim.notify("[dotnet-tools] Package search failed with exit code " .. code, vim.log.levels.ERROR)
				callback(nil)
			end
		end,
	})
end

-- Helper function to get available versions for a package
local function get_package_versions(package_id, callback)
	vim.notify("[dotnet-tools] Fetching versions for " .. package_id .. "...", vim.log.levels.INFO)

	local config = require("dotnet-tools.config").options
	local include_prerelease = config.nuget.include_prerelease and "--prerelease" or ""

	local cmd = string.format(
		"dotnet package search %s --exact-match %s --take 100 --format json",
		vim.fn.shellescape(package_id),
		include_prerelease
	)

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data, _)
			if not data or #data == 0 then
				vim.notify("[dotnet-tools] No version data received", vim.log.levels.WARN)
				callback(nil)
				return
			end

			local json_str = table.concat(data, "\n")
			if json_str == "" or json_str == "\n" then
				vim.notify("[dotnet-tools] Empty version response", vim.log.levels.WARN)
				callback(nil)
				return
			end

			local ok, results = pcall(vim.fn.json_decode, json_str)
			if not ok then
				vim.notify("[dotnet-tools] Failed to parse version JSON: " .. tostring(results), vim.log.levels.ERROR)
				callback(nil)
				return
			end

			if not results or not results.searchResult or #results.searchResult == 0 then
				vim.notify("[dotnet-tools] No version results in response", vim.log.levels.WARN)
				callback(nil)
				return
			end

			local first_source = results.searchResult[1]
			if not first_source or not first_source.packages or #first_source.packages == 0 then
				vim.notify("[dotnet-tools] No version packages found for " .. package_id, vim.log.levels.WARN)
				callback(nil)
				return
			end

			-- Extract versions from packages array (each package has a version field)
			local versions = {}
			local seen = {}

			for _, pkg in ipairs(first_source.packages) do
				if pkg.version and not seen[pkg.version] then
					table.insert(versions, pkg.version)
					seen[pkg.version] = true
				end
			end

			if #versions == 0 then
				vim.notify("[dotnet-tools] No versions found for " .. package_id, vim.log.levels.WARN)
				callback(nil)
				return
			end

			-- Reverse to show newest first
			local reversed_versions = {}
			for i = #versions, 1, -1 do
				table.insert(reversed_versions, versions[i])
			end

			vim.notify(
				string.format("[dotnet-tools] Found %d versions", #reversed_versions),
				vim.log.levels.INFO
			)
			callback(reversed_versions)
		end,
		on_stderr = function(_, data, _)
			if data and #data > 0 then
				local err = table.concat(data, "\n")
				if err and err ~= "" and err ~= "\n" then
					vim.notify("[dotnet-tools] Version fetch error: " .. err, vim.log.levels.ERROR)
				end
			end
		end,
		on_exit = function(_, code, _)
			if code ~= 0 then
				vim.notify("[dotnet-tools] Failed to fetch versions with exit code " .. code, vim.log.levels.ERROR)
				callback(nil)
			end
		end,
	})
end

-- Helper function to find Directory.Packages.props
local function find_directory_packages_props(start_dir)
	local current = start_dir

	-- Search up to 5 levels up
	for _ = 1, 5 do
		local props_path = current .. "/Directory.Packages.props"
		local file = io.open(props_path, "r")
		if file then
			file:close()
			return props_path
		end

		-- Move up one directory
		local parent = vim.fn.fnamemodify(current, ":h")
		if parent == current then
			break -- Reached root
		end
		current = parent
	end

	return nil
end

-- Helper function to parse Directory.Packages.props for central package versions
local function get_central_package_versions(props_path)
	local file = io.open(props_path, "r")
	if not file then
		return {}
	end

	local content = file:read("*all")
	file:close()

	local versions = {}

	-- Parse PackageVersion elements: <PackageVersion Include="PackageName" Version="1.0.0" />
	for include, version in content:gmatch('<PackageVersion%s+Include="([^"]+)"%s+Version="([^"]+)"') do
		versions[include] = version
	end

	-- Also handle reverse order
	for version, include in content:gmatch('<PackageVersion%s+Version="([^"]+)"%s+Include="([^"]+)"') do
		if not versions[include] then
			versions[include] = version
		end
	end

	return versions
end

-- Helper function to get installed packages from .csproj
local function get_installed_packages(project_root)
	local csproj_files = vim.fn.glob(project_root .. "/*.csproj", false, true)

	if #csproj_files == 0 then
		vim.notify("[dotnet-tools] No .csproj file found in project root", vim.log.levels.ERROR)
		return nil
	end

	local csproj_path = csproj_files[1]
	local file = io.open(csproj_path, "r")
	if not file then
		vim.notify("[dotnet-tools] Failed to open .csproj file", vim.log.levels.ERROR)
		return nil
	end

	local content = file:read("*all")
	file:close()

	-- Check for Central Package Management
	local props_path = find_directory_packages_props(project_root)
	local central_versions = {}

	if props_path then
		central_versions = get_central_package_versions(props_path)
		vim.notify("[dotnet-tools] Using Central Package Management from " .. props_path, vim.log.levels.INFO)
	end

	-- Parse PackageReference elements
	local packages = {}
	local seen = {}

	-- Pattern 1: Find all PackageReference Include attributes (with or without whitespace)
	for include in content:gmatch('<PackageReference[^>]*Include="([^"]+)"') do
		if not seen[include] then
			seen[include] = true

			-- Try to extract inline version from the same PackageReference tag
			-- Match the full tag to extract version if present
			local tag_pattern = '<PackageReference[^>]*Include="' .. include:gsub("([%.%-])", "%%%1") .. '"[^>]*>'
			local full_tag = content:match(tag_pattern)

			local version = nil
			if full_tag then
				version = full_tag:match('Version="([^"]+)"')
			end

			-- If no inline version, check Central Package Management
			if not version then
				version = central_versions[include]
			end

			if version then
				table.insert(packages, { name = include, version = version })
			else
				-- Package reference exists but no version found (might be in a different ItemGroup or using a variable)
				table.insert(packages, { name = include, version = "unknown" })
			end
		end
	end

	return packages
end

-- Public function: Search and install a NuGet package
M.search_and_install = function()
	if not check_dotnet_available() then
		return
	end

	local current_dir = vim.fn.expand("%:p:h")
	local project_root = helpers.find_project_root_by_csproj(current_dir)

	if not project_root then
		vim.notify("[dotnet-tools] No .csproj file found in parent directories", vim.log.levels.ERROR)
		return
	end

	-- Step 1: Get search query from user
	vim.ui.input({ prompt = "Search NuGet packages: " }, function(query)
		if not query or query == "" then
			return
		end

		-- Step 2: Search for packages
		search_nuget(query, function(search_results)
			if not search_results then
				return
			end

			-- Step 3: Let user select a package
			vim.ui.select(search_results.packages, {
				prompt = "Select package to install:",
			}, function(choice)
				if not choice then
					return
				end

				local selected_package = search_results.map[choice]

				-- Step 4: Fetch versions for the selected package
				get_package_versions(selected_package.id, function(versions)
					if not versions or #versions == 0 then
						vim.notify("[dotnet-tools] No versions available for " .. selected_package.id, vim.log.levels.ERROR)
						return
					end

					-- Step 5: Let user select a version
					vim.ui.select(versions, {
						prompt = "Select version to install:",
					}, function(version_choice)
						if not version_choice then
							return
						end

						-- Step 6: Install the package
						vim.notify(
							"[dotnet-tools] Installing " .. selected_package.id .. " " .. version_choice .. "...",
							vim.log.levels.INFO
						)

						local install_cmd = string.format(
							"cd %s && dotnet add package %s --version %s",
							vim.fn.shellescape(project_root),
							vim.fn.shellescape(selected_package.id),
							vim.fn.shellescape(version_choice)
						)

						local result = vim.fn.system(install_cmd)
						if vim.v.shell_error ~= 0 then
							vim.notify(
								"[dotnet-tools] Failed to install package:\n" .. result,
								vim.log.levels.ERROR
							)
							return
						end

						vim.notify(
							"[dotnet-tools] Successfully installed " .. selected_package.id .. " " .. version_choice,
							vim.log.levels.INFO
						)
					end)
				end)
			end)
		end)
	end)
end

-- Public function: List installed packages and update selected package
M.list_packages = function()
	if not check_dotnet_available() then
		return
	end

	local current_dir = vim.fn.expand("%:p:h")
	local project_root = helpers.find_project_root_by_csproj(current_dir)

	if not project_root then
		vim.notify("[dotnet-tools] No .csproj file found in parent directories", vim.log.levels.ERROR)
		return
	end

	local packages = get_installed_packages(project_root)

	if not packages or #packages == 0 then
		vim.notify("[dotnet-tools] No NuGet packages installed in this project", vim.log.levels.INFO)
		return
	end

	-- Step 1: Let user select a package from installed packages
	local package_names = {}
	for _, pkg in ipairs(packages) do
		table.insert(package_names, string.format("%s (%s)", pkg.name, pkg.version))
	end

	vim.ui.select(package_names, {
		prompt = "Select package to update:",
	}, function(choice)
		if not choice then
			return
		end

		-- Extract package name
		local package_name = choice:match("^(.+)%s+%(")

		-- Step 2: Fetch available versions
		get_package_versions(package_name, function(versions)
			if not versions or #versions == 0 then
				vim.notify("[dotnet-tools] No versions available for " .. package_name, vim.log.levels.ERROR)
				return
			end

			-- Step 3: Let user select a version
			vim.ui.select(versions, {
				prompt = "Select version to update to:",
			}, function(version_choice)
				if not version_choice then
					return
				end

				-- Step 4: Update the package
				vim.notify(
					"[dotnet-tools] Updating " .. package_name .. " to " .. version_choice .. "...",
					vim.log.levels.INFO
				)

				local update_cmd = string.format(
					"cd %s && dotnet add package %s --version %s",
					vim.fn.shellescape(project_root),
					vim.fn.shellescape(package_name),
					vim.fn.shellescape(version_choice)
				)

				local result = vim.fn.system(update_cmd)
				if vim.v.shell_error ~= 0 then
					vim.notify("[dotnet-tools] Failed to update package:\n" .. result, vim.log.levels.ERROR)
					return
				end

				vim.notify(
					"[dotnet-tools] Successfully updated " .. package_name .. " to " .. version_choice,
					vim.log.levels.INFO
				)
			end)
		end)
	end)
end


-- Public function: Remove a package
M.remove_package = function()
	if not check_dotnet_available() then
		return
	end

	local current_dir = vim.fn.expand("%:p:h")
	local project_root = helpers.find_project_root_by_csproj(current_dir)

	if not project_root then
		vim.notify("[dotnet-tools] No .csproj file found in parent directories", vim.log.levels.ERROR)
		return
	end

	local packages = get_installed_packages(project_root)

	if not packages or #packages == 0 then
		vim.notify("[dotnet-tools] No NuGet packages installed in this project", vim.log.levels.INFO)
		return
	end

	-- Let user select a package to remove
	local package_names = {}
	for _, pkg in ipairs(packages) do
		table.insert(package_names, string.format("%s (%s)", pkg.name, pkg.version))
	end

	vim.ui.select(package_names, {
		prompt = "Select package to remove:",
	}, function(choice)
		if not choice then
			return
		end

		-- Extract package name
		local package_name = choice:match("^(.+)%s+%(")

		-- Confirm removal
		local confirm = vim.fn.confirm(
			"Remove package " .. package_name .. "?",
			"&Yes\n&No",
			2
		)

		if confirm ~= 1 then
			return
		end

		-- Remove the package
		vim.notify("[dotnet-tools] Removing " .. package_name .. "...", vim.log.levels.INFO)

		local remove_cmd = string.format(
			"cd %s && dotnet remove package %s",
			vim.fn.shellescape(project_root),
			vim.fn.shellescape(package_name)
		)

		local result = vim.fn.system(remove_cmd)
		if vim.v.shell_error ~= 0 then
			vim.notify("[dotnet-tools] Failed to remove package:\n" .. result, vim.log.levels.ERROR)
			return
		end

		vim.notify("[dotnet-tools] Successfully removed " .. package_name, vim.log.levels.INFO)
	end)
end

return M
