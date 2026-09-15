local Path = {}

--- @param absolutePath string
--- @param relativePath string
--- @param rootPath? string
--- @param rootPaths? table<string, string>
--- @return string
function Path.resolve(absolutePath, relativePath, rootPath, rootPaths)
	if rootPaths then
		local r = {}
		for key, value in pairs(rootPaths) do
			r[key] = "/" .. value
		end

		absolutePath = absolutePath:gsub("^@([%w_%-]+)", r)
		relativePath = relativePath:gsub("^@([%w_%-]+)", r)
	end

	if rootPath then
		absolutePath = absolutePath:gsub("^(@)", "/" .. rootPath)
		relativePath = relativePath:gsub("^(@)", "/" .. rootPath)
	end

	absolutePath = absolutePath:gsub("//+", "/")
	relativePath = relativePath:gsub("//+", "/")

	if relativePath:match("^/") then
		local result = relativePath:gsub("^/", "")
		return result
	end

	local resultPathComponents = {}
	for segment in absolutePath:gmatch("[^/]+") do
		table.insert(resultPathComponents, segment)
	end

	if #resultPathComponents > 0 then
		if love.filesystem.getInfo(absolutePath, "file") then
			table.remove(resultPathComponents)
		end
	end

	local relativeSegments = {}
	for segment in relativePath:gmatch("[^/]+") do
		table.insert(relativeSegments, segment)
	end

	for i, segment in ipairs(relativeSegments) do
		if i == 1 and segment == "@" then
			if rootPath then
				table.insert(resultPathComponents, rootPath)
			end
		elseif segment == "." then
			-- Nothing.
		elseif segment == ".." then
			if #resultPathComponents > 0 then
				table.remove(resultPathComponents)
			end
		else
			table.insert(resultPathComponents, segment)
		end
	end

	return table.concat(resultPathComponents, "/")
end

--- @param absolutePath string
--- @param path string
function Path.makeRelative(absolutePath, path)
	absolutePath =
		absolutePath:gsub("\\", "/"):gsub("//+", "/"):gsub("([^/])$", "%1/")
	path = path:gsub("\\", "/"):gsub("//+", "/")

	local i, j = path:find(absolutePath, 1, true)
	if i and j and i == 1 then
		return path:sub(j + 1)
	end

	return path
end

return Path
