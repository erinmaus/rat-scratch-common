local Debug = require("rat-scratch-common").Debug
local Path = require("rat-scratch-common").Path

--- @alias RatScratch.Graphics.ShaderPreprocessOptions {
---   warnings?: boolean,
---   errors?: boolean,
---   safe?: boolean,
---   dependencies?: boolean,
---   rootPath?: string | false,
--- }

local DEFAULT_OPTIONS = {
	warnings = true,
	errors = true,
	safe = true,
	dependencies = false,
	rootPath = false
}

--- @alias RatScratch.Graphics.ShaderPreprocessResult {
---   warnings?: string[],
---   errors?: string[],
---   dependencies?: string[],
--- }

--- @alias RatScratch.Graphics.impl.ShaderHoistedOption {
---   value: string,
---   filename: string,
---   currentLine: number,
--- }

--- @alias RatScratch.Graphics.impl.ShaderHoistedOptions {
---   order: string[],
---   keys: table<string, RatScratch.Graphics.impl.ShaderHoistedOption>,
--- }

--- @alias RatScratch.Graphics.impl.ShaderProcessFile {
---   parent?: RatScratch.Graphics.impl.ShaderProcessFile,
---   filename: string,
---   currentLineNumber: number,
--- }

--- @alias RatScratch.Graphics.impl.ShaderProcessState {
---   options: RatScratch.Graphics.ShaderPreprocessOptions,
---   visited: table<string, boolean>,
---   hoistedOptions: RatScratch.Graphics.impl.ShaderHoistedOptions,
---   result: RatScratch.Graphics.ShaderPreprocessResult,
---   dependencies: table<string, boolean>,
--- }

--- @param state RatScratch.Graphics.impl.ShaderProcessState
--- @param? parent RatScratch.Graphics.impl.ShaderProcessFile
--- @param filename string
--- @return? RatScratch.Graphics.impl.ShaderProcessFile
local function beginVisit(state, parent, filename)
	if state.visited[filename] then
		local errorMessage = string.format(
			"%s:0: recursive import for `%s`",
			parent and parent.filename or "<root>",
			parent and parent.currentLineNumber or 1,
			filename
		)

		if state.options.safe then
			table.insert(state.result.errors, errorMessage)
			return nil
		else
			error(errorMessage)
		end
	end

	state.visited[filename] = true
	state.dependencies[filename] = true

	return {
		parent = parent,
		filename = filename,
		currentLineNumber = 0,
	}
end

--- @param state RatScratch.Graphics.impl.ShaderProcessState
--- @param currentFile RatScratch.Graphics.impl.ShaderProcessFile
local function endVisit(state, currentFile)
	assert(state.visited[currentFile.filename] ~= nil, "ending visit, but current file not in visit table")
	state.visited[currentFile.filename] = nil
end

local LINE_PATTERN = "([^\r\n]*[\r\n]?)"
local TRIMMED_LINE_PATTERN = "^%s*(.-)%s*$"
local INCLUDE_PATTERN = '^#include "([^"]+)"'
local PRAGMA_OPTION_PATTERN = "^#pragma option%s+([%w_]+)%s*(.*)"
local FUNCTION_OPTION_VALUE_PATTERN = "%((.-)%)"
local PRAGMA_LANGUAGE_PATTERN = "^#pragma language%s+([^\n\r]+)"

--- @param state RatScratch.Graphics.impl.ShaderProcessState
--- @param currentFile RatScratch.Graphics.impl.ShaderProcessFile
local function readContent(state, currentFile)
	local content = love.filesystem.read(currentFile.filename)
	if content then
		return content
	end

	local errorMessage = string.format("%s:0: failed to read file", currentFile.filename)
	if state.options.safe then
		table.insert(state.result.errors, errorMessage)
		return string.format('// file "%s" not found', currentFile.filename)
	else
		error(errorMessage)
	end
end

--- @param state RatScratch.Graphics.impl.ShaderProcessState
--- @param parent? RatScratch.Graphics.impl.ShaderProcessFile
--- @param filename string
--- @param rootPath? string
--- @return string
local function process(state, parent, filename, rootPath)
	local currentFile = beginVisit(state, parent, filename)
	if not currentFile then
		return string.format('// file "%s" is recursively included', filename)
	end

	local content = readContent(state, currentFile)
	local lines = {}
	for line in content:gmatch(LINE_PATTERN) do
		currentFile.currentLineNumber = currentFile.currentLineNumber + 1

		local trimmedLine = line:gsub(TRIMMED_LINE_PATTERN, "%1")

		local includeFilename = trimmedLine:match(INCLUDE_PATTERN)
		local optionName, optionValue = trimmedLine:match(PRAGMA_OPTION_PATTERN)

		if includeFilename then
			local resolvedPath = Path.resolve(filename, includeFilename, rootPath)

			table.insert(lines, string.format("// %s", line))
			local includedContent = process(state, currentFile, resolvedPath, rootPath)

			table.insert(lines, "#line 1")
			table.insert(lines, includedContent)
			table.insert(lines, string.format('// end "%s"', includeFilename))
			table.insert(lines, string.format("#line %d\n", currentFile.currentLineNumber + 1))
		elseif optionName and optionValue then
			if state.hoistedOptions.keys[optionName] then
				if state.options.warnings then
					table.insert(
						state.result.warnings,
						string.format(
							"%s:%d: duplicate option '%s'; ignoring",
							filename,
							currentFile.currentLineNumber,
							optionName
						)
					)
				end
			else
				table.insert(state.hoistedOptions.order, optionName)
			end

			state.hoistedOptions.keys[optionName] = {
				value = optionValue,
				filename = filename,
				currentLine = currentFile.currentLineNumber,
			}

			table.insert(lines, string.format("// %s", line))
		else
			table.insert(lines, line)
		end
	end

	endVisit(state, currentFile)

	return table.concat(lines, "\n")
end

--- @param state RatScratch.Graphics.impl.ShaderProcessState
--- @param lines string[]
local function tryHoistOptions(state, lines)
	local hoistedOptionsOrder = state.hoistedOptions.order
	local hoistedOptionsKeys = state.hoistedOptions.keys

	for _, name in ipairs(hoistedOptionsOrder) do
		local data = hoistedOptionsKeys[name]
		local trimmedValue = data.value:gsub(TRIMMED_LINE_PATTERN, "%1")

		if trimmedValue == "" then
			table.insert(lines, string.format("#define %s", name))
		elseif trimmedValue:match(FUNCTION_OPTION_VALUE_PATTERN) then
			table.insert(lines, string.format("#define %s%s", name, trimmedValue))
		else
			table.insert(lines, string.format("#define %s %s", name, trimmedValue))
		end
	end
end

--- @param state RatScratch.Graphics.impl.ShaderProcessState
--- @param content string
--- @param lines string[]
local function tryHoistLanguagePragma(state, content, lines)
	local language = content:match(PRAGMA_LANGUAGE_PATTERN)

	if language then
		table.insert(lines, 1, string.format("#pragma language %s", language))
		return content:gsub(PRAGMA_LANGUAGE_PATTERN, "")
	end

	return content
end

local ShaderPreprocessor = {}

--- @param filename string
--- @param options? RatScratch.Graphics.ShaderPreprocessOptions
--- @return string
--- @return RatScratch.Graphics.ShaderPreprocessResult
function ShaderPreprocessor.preprocess(filename, options)
	options = options or {}

	--- @type RatScratch.Graphics.ShaderPreprocessOptions
	local mergedOptions = {}
	for optionKey, defaultOptionValue in pairs(DEFAULT_OPTIONS) do
		if options[optionKey] == nil then
			mergedOptions[optionKey] = defaultOptionValue
		else
			mergedOptions[optionKey] = options[optionKey]
		end
	end

	local hasResult = mergedOptions.safe or mergedOptions.warnings or mergedOptions.dependencies
	local result = hasResult
			and {
				warnings = mergedOptions.warnings and {} or nil,
				errors = mergedOptions.errors and {} or nil,
				dependencies = mergedOptions.dependencies and {} or nil,
			}
		or nil

	local hoistedOptions = { keys = {}, order = {} }
	local visited = {}
	local dependencies = {}

	local processedState = {
		hoistedOptions = hoistedOptions,
		visited = visited,
		options = mergedOptions,
		result = result,
		dependencies = dependencies,
	}

	local absoluteFilename = Path.resolve("", filename, mergedOptions.rootPath)
	local processedContent = process(processedState, nil, absoluteFilename, mergedOptions.rootPath)

	local finalOutput = {}
	tryHoistOptions(processedState, finalOutput)
	processedContent = tryHoistLanguagePragma(processedState, processedContent, finalOutput)
	table.insert(finalOutput, processedContent)

	if result and mergedOptions.dependencies then
		for filename in pairs(dependencies) do
			table.insert(result.dependencies, filename)
		end

		table.sort(result.dependencies)
	end

	return table.concat(finalOutput, "\n"), result
end

--- @param result RatScratch.Graphics.ShaderPreprocessResult
--- @param shader? string
--- @param strict? boolean
--- @return string?
function ShaderPreprocessor.validateResult(shader, result, strict)
	if strict == nil then
		strict = true
	end

	if not (#result.warnings > 0 and strict) and #result.errors == 0 then
		return nil
	end

	local combinedMessage = {}
	if #result.warnings > 0 and strict then
		for _, warning in ipairs(result.warnings) do
			table.insert(combinedMessage, string.format("warning: %s", warning))
		end
	end

	if #result.errors > 0 then
		for _, e in ipairs(result.errors) do
			table.insert(combinedMessage, string.format("error: %s", e))
		end
	end

	if shader and shader ~= "" then
		table.insert(combinedMessage, string.format("shader source: %s", shader))
	else
		table.insert(combinedMessage, "no shader source")
	end

	return table.concat(combinedMessage, "\n")
end

--- @param filename string
--- @param options? RatScratch.Graphics.ShaderPreprocessOptions
--- @return love.Shader
function ShaderPreprocessor.newComputeShader(filename, options)
	local source, result = ShaderPreprocessor.preprocess(filename, options)
	local message = ShaderPreprocessor.validateResult(source, result)
	if message then
		error(message)
	end

	local success, shader = pcall(love.graphics.newComputeShader, source)
	Debug.assert(success, "%s\n%s", shader, source)

	return shader
end

--- @param pixelFilename string
--- @param vertexFilename string
--- @param options? RatScratch.Graphics.ShaderPreprocessOptions
--- @return love.Shader
function ShaderPreprocessor.newShader(pixelFilename, vertexFilename, options)
	Debug.assert(pixelFilename, "expected shader filename or vertex/pixel shader filenames")

	local pixelSource
	do
		local s, r = ShaderPreprocessor.preprocess(pixelFilename, options)
		local m = ShaderPreprocessor.validateResult(s, r)
		if m then
			error(m)
		end

		pixelSource = s
	end

	local vertexSource
	if vertexFilename then
		local s, r = ShaderPreprocessor.preprocess(vertexFilename, options)
		local m = ShaderPreprocessor.validateResult(s, r)
		if m then
			error(m)
		end

		vertexSource = s
	end

	if vertexSource and pixelSource then
		return love.graphics.newShader(pixelSource, vertexSource)
	else
		return love.graphics.newShader(pixelSource)
	end
end

return ShaderPreprocessor
