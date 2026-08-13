local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Pack = require("rat-scratch-pipeline.Utility.Pack")

--- @class RatScratch.Pipeline.VertexBufferFormat : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Pipeline.PipelineDefinitionVertexBufferAttribute[]): RatScratch.Pipeline.VertexBufferFormat
--- @field private inputFormatInstance RatScratch.Graphics.Graphics3D.BufferFormat
--- @field private vertexFormatInstance RatScratch.Graphics.Graphics3D.BufferFormat
--- @field private transforms { pack: fun(...: number): ...: number; unpack: fun(...: number): ...: number }[]
--- @field private bufferToRole string<string, string>
--- @field private roleToBuffer string<string, string>
local VertexBufferFormat = Object()

--- @param format RatScratch.Pipeline.PipelineDefinitionVertexBufferAttribute[]
function VertexBufferFormat:new(format)
	local inputFormat = {}
	local vertexFormat = {}

	self.transforms = {}
	self.bufferToRole = {}
	self.roleToBuffer = {}

	local inputScalar = BufferFormat.getFormatScalar(format[1].inputFormat)
	for i, attribute in ipairs(format) do
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

		assert(
			not self.bufferToRole[attribute.role],
			"vertex attribute with role %s duplicated",
			attribute.role
		)

		assert(
			not self.roleToBuffer[attribute.buffer],
			"vertex attribute with buffer %s duplicated",
			attribute.buffer
		)

		self.roleToBuffer[attribute.role] = attribute.buffer
		self.bufferToRole[attribute.buffer] = attribute.role

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
			name = attribute.role,
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
				unpack = unpack,
			}
		end
	end

	self.inputFormatInstance = BufferFormat(inputFormat)
	self.vertexFormatInstance = BufferFormat(vertexFormat)
end

function VertexBufferFormat:getInputFormat()
	return self.inputFormatInstance
end

function VertexBufferFormat:getVertexFormat()
	return self.vertexFormatInstance
end

--- @param role string
--- @return boolean
function VertexBufferFormat:hasRole(role)
	return self.roleToBuffer[role] ~= nil
end

--- @param role string
--- @return string
function VertexBufferFormat:getBufferName(role)
	return self.roleToBuffer[role]
end

--- @param buffer string
--- @return string
function VertexBufferFormat:getRoleFromBufferName(buffer)
	return self.bufferToRole[buffer]
end

--- @param role string
--- @param ... number
--- @return number ...
function VertexBufferFormat:pack(role, ...)
	local transform = self.transforms[role]
	if not transform then
		return ...
	end

	return transform.pack(...)
end

--- @param role string
--- @param ... number
--- @return number ...
function VertexBufferFormat:unpack(role, ...)
	local transform = self.transforms[role]
	if not transform then
		return ...
	end

	return transform.unpack(...)
end

return VertexBufferFormat
