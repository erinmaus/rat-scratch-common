local Path = {}

--- @param absolutePath string
--- @param relativePath string
--- @param rootPath? string
--- @return string
function Path.resolve(absolutePath, relativePath, rootPath)
	if rootPath then
		absolutePath = absolutePath:gsub("^(@)", rootPath)
		relativePath = relativePath:gsub("^(@)", rootPath)
	end

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

return Path
