local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Pack = require("rat-scratch-pipeline.Utility.Pack")

--- @class RatScratch.Pipeline.VertexBufferInfo : RatScratch.Common.BaseObject
--- @overload fun(info: RatScratch.Pipeline.PipelineDefinitionVertexBuffer): RatScratch.Pipeline.VertexBufferInfo
--- @field private inputFormatInstance RatScratch.Graphics.Graphics3D.BufferFormat
--- @field private vertexFormatInstance RatScratch.Graphics.Graphics3D.BufferFormat
--- @field private transforms table<string, { packName: string, unpackName: string, pack: fun(...: number): ...: number; unpack: fun(...: number): ...: number }>
--- @field private buffer string
local VertexBufferInfo = Object()

--- @param info RatScratch.Pipeline.PipelineDefinitionVertexBuffer
function VertexBufferInfo:new(info)
	local inputFormat = {}
	local vertexFormat = {}

	self.transforms = {}
	self.buffer = info.buffer

	local inputScalar = BufferFormat.getFormatScalar(info.format[1].inputFormat)
	for i, attribute in ipairs(info.format) do
		local inputAttributeScalar =
			BufferFormat.getFormatScalar(attribute.inputFormat)
		assert(
			inputScalar == inputAttributeScalar,
			"input attribute %d (%s) in input buffer format mis-match: all pre-transformed input attributes must have same base scalar type, got %s, expected %s",
			i,
			attribute.role,
			inputAttributeScalar,
			inputScalar
		)

		local inputAttribute = {
			location = BufferFormat.getFormatAttributeLocationFromName(
				attribute.role
			),
			name = attribute.role,
			format = attribute.inputFormat,
		}
		table.insert(inputFormat, inputAttribute)

		local vertexAttribute = {
			location = BufferFormat.getFormatAttributeLocationFromName(
				attribute.role
			),
			name = attribute.name,
			format = attribute.vertexFormat,
		}
		table.insert(vertexFormat, vertexAttribute)

		if attribute.transform then
			local pack = Pack[attribute.transform.to]
			local unpack = Pack[attribute.transform.from]

			assert(
				pack,
				"unrecognized pack transform function %s",
				attribute.transform.to
			)

			assert(
				unpack,
				"unrecognized unpack transform function %s",
				attribute.transform.from
			)

			self.transforms[attribute.role] = {
				pack = pack,
				packName = attribute.transform.to,
				unpack = unpack,
				unpackName = attribute.transform.from,
			}
		end
	end

	self.inputFormatInstance = BufferFormat(inputFormat, true)
	self.vertexFormatInstance = BufferFormat(vertexFormat, true)
end

function VertexBufferInfo:getInputFormat()
	return self.inputFormatInstance
end

function VertexBufferInfo:getVertexFormat()
	return self.vertexFormatInstance
end

--- @return string
function VertexBufferInfo:getBufferName()
	return self.buffer
end

--- @param role string
--- @return string
function VertexBufferInfo:getPackTransform(role)
	local transform = self.transforms[role]
	return transform and transform.packName
end

--- @param role string
--- @return string
function VertexBufferInfo:getUnpackTransform(role)
	local transform = self.transforms[role]
	return transform and transform.unpackName
end

--- @param role string
--- @param ... number
--- @return number ...
function VertexBufferInfo:pack(role, ...)
	local transform = self.transforms[role]
	if not transform then
		return ...
	end

	return transform.pack(...)
end

--- @param role string
--- @param ... number
--- @return number ...
function VertexBufferInfo:unpack(role, ...)
	local transform = self.transforms[role]
	if not transform then
		return ...
	end

	return transform.unpack(...)
end

return VertexBufferInfo
