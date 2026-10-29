local Object = require("rat-scratch-common").Object
local ResourceType = require("rat-scratch-resource").ResourceType
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor
local ShaderResourceTypeCommon =
	require("rat-scratch-pipeline.impl.ShaderResourceTypeCommon")

--- @class RatScratch.Pipeline.ShaderResourceType.ResourceArguments
--- @field public vertexFilename? string
--- @field public pixelFilename? string
--- @field public computeFilename? string
--- @field public options? RatScratch.Graphics.ShaderPreprocessOptions
local ShaderResourceTypeResourceArguments = {}

--- @class RatScratch.Pipeline.ShaderResourceType.Data
--- @field public compute? string
--- @field public pixel? string
--- @field public vertex? string
local ShaderResourceTypeData = {}

--- @param args RatScratch.Pipeline.ShaderResourceType.ResourceArguments
--- @return RatScratch.Pipeline.ShaderResourceType.ResourceArguments
local function _getResourceArguments(args)
	if type(args) == "string" then
		return {
			pixelFilename = args,
			options = ShaderResourceTypeCommon.mergePreprocessOptions(),
		}
	end

	return {
		pixelFilename = args.pixelFilename,
		vertexFilename = args.vertexFilename,
		computeFilename = args.computeFilename,
		options = ShaderResourceTypeCommon.mergePreprocessOptions(args.options),
	}
end

--- @class RatScratch.Pipeline.ShaderResourceType : RatScratch.Resource.ResourceType<love.Shader, RatScratch.Pipeline.ShaderResourceType.Data>
--- @overload fun(): RatScratch.Resource.ResourceType<love.Shader, RatScratch.Pipeline.ShaderResourceType.Data>
local ShaderResourceType = Object(ResourceType)

--- comment
--- @param args RatScratch.Pipeline.ShaderResourceType.ResourceArguments
--- @param parentPath string
--- @return string ...
function ShaderResourceType:resolvePath(args, parentPath)
	if args.computeFilename then
		return ResourceType.resolvePath(self, args.computeFilename, parentPath)
	elseif args.pixelFilename and args.vertexFilename then
		return ResourceType.resolvePath(self, args.pixelFilename, parentPath),
			ResourceType.resolvePath(self, args.vertexFilename, parentPath)
	elseif args.pixelFilename or args.vertexFilename then
		return ResourceType.resolvePath(
			self,
			--- @diagnostic disable-next-line: param-type-mismatch
			args.pixelFilename or args.vertexFilename,
			parentPath
		)
	end
end

--- @param hint RatScratch.Pipeline.ShaderResourceType.Data
function ShaderResourceType:createDefaultResource(hint)
	if hint and hint.compute then
		return {
			compute = [[
				void computemain()
				{
					// Nothing.
				}
			]],
		}
	end

	return {
		pixel = [[
				#ifdef VERTEX

				vec4 position(mat4 transform, vec4 p)
				{
					return transform * p;
				}

				#endif

				#ifdef PIXEL

				vec4 effect(vec4 color, Image image, vec2 textureCoordinates, vec2 screenCoordinates)
				{
					vec4 imageSample = texture(image, textureCoordinates);
					return imageSample * color * vec4(1.0, 0.5, 0.5, 1.0);
				}

				#endif
		]],
	}
end

local SOURCES = {
	{ inputKey = "computeFilename", sourceKey = "compute" },
	{ inputKey = "pixelFilename", sourceKey = "pixel" },
	{ inputKey = "vertexFilename", sourceKey = "vertex" },
}

--- @param filename table
function ShaderResourceType:loadDataFromFile(filename)
	local args = _getResourceArguments(filename)

	assert(
		not args.computeFilename
			or not (args.vertexFilename or args.pixelFilename),
		"shader mis-match; compute cannot have vertex/pixel stages"
	)
	assert(
		args.pixelFilename or args.vertexFilename or args.computeFilename,
		"must have one filename"
	)

	local result = {}
	local workingDependencies = {}
	for _, sourceInfo in ipairs(SOURCES) do
		local shaderSource
		if args[sourceInfo.inputKey] then
			local s, o = ShaderPreprocessor.preprocess(
				args[sourceInfo.inputKey],
				args.options
			)
			local r = ShaderPreprocessor.validateResult(s, o, true)
			if r then
				error(r)
			end

			shaderSource = s

			if o then
				for _, d in ipairs(o.dependencies) do
					workingDependencies[d] = true
				end
			end
		end

		if shaderSource then
			result[sourceInfo.sourceKey] = shaderSource
		end
	end

	local dependencies = {}
	for d in pairs(workingDependencies) do
		table.insert(dependencies, d)
	end
	table.sort(dependencies)

	return result, dependencies
end

--- @param resource RatScratch.Resource.Resource<love.Shader>
--- @param data RatScratch.Pipeline.ShaderResourceType.Data
function ShaderResourceType:updateFromData(resource, data)
	if data.compute then
		resource:set(love.graphics.newComputeShader(data.compute))
	else
		resource:set(
			love.graphics.newShader(data.pixel, data.vertex, { write = true })
		)
	end

	return resource
end

return ShaderResourceType
