local Object = require("rat-scratch-common").Object
assert = require("rat-scratch-common").Debug.assert

--- @class RatScratch.GLTF.GLTFAttributes : RatScratch.Common.BaseObject
--- @field private attributeToVertexElement table<string, string>
--- @field private vertexElementToAttribute table<string, string>
--- @field private locationToVertexElement table<number, string>
--- @field private vertexElementToLocation table<string, number>
--- @field private format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
local GLTFAttributes = Object()

GLTFAttributes.DEFAULT_VERTEX_ELEMENT_TO_GLTF_ATTRIBUTE = {
	VertexPosition = "POSITION",
	VertexTexCoord = "TEXCOORD_0",
	VertexColor = "COLOR_0",
	VertexNormal = "NORMAL",
	VertexBoneIndex = "JOINTS_0",
	VertexBoneWeight = "WEIGHTS_0",
}

function GLTFAttributes:new()
	self.attributeToVertexElement = {}
	self.vertexElementToAttribute = {}
	self.locationToVertexElement = {}
	self.vertexElementToLocation = {}
	self.format = {}
end

function GLTFAttributes.makeDefault()
	local result = GLTFAttributes()

	result:defineAttribute("POSITION", "VertexPosition", 0, "floatvec4")
	result:defineAttribute("TEXCOORD_0", "VertexTexCoord", 1, "floatvec4")
	result:defineAttribute("COLOR_0", "VertexColor", 2, "floatvec4")
	result:defineAttribute("NORMAL", "VertexNormal", 10, "floatvec4")
	result:defineAttribute("JOINTS_0", "VertexBoneIndex", 20, "uint32vec4")
	result:defineAttribute("WEIGHTS_0", "VertexBoneWeight", 21, "floatvec4")

	return result
end

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param vertexElementToGLTFAttribute? table<string, string>
function GLTFAttributes.fromFormat(format, vertexElementToGLTFAttribute)
	local result = GLTFAttributes()

	for _, attribute in ipairs(format) do
		local gltfAttributeName = vertexElementToGLTFAttribute
				and vertexElementToGLTFAttribute[attribute.name]
			or GLTFAttributes.DEFAULT_VERTEX_ELEMENT_TO_GLTF_ATTRIBUTE[attribute.name]
		assert(
			gltfAttributeName,
			"could not map vertex attribute '%s' to GLTF attribute name",
			attribute.name
		)

		result:defineAttribute(
			gltfAttributeName,
			attribute.name,
			attribute.location,
			attribute.format
		)
	end

	return result
end

function GLTFAttributes:hasAttribute(attributeName)
	return self.attributeToVertexElement[attributeName] ~= nil
end

function GLTFAttributes:hasVertexElement(vertexElementName)
	return self.vertexElementToAttribute[vertexElementName] ~= nil
end

function GLTFAttributes:hasLocation(location)
	return self.locationToVertexElement[location] ~= nil
end

function GLTFAttributes:getVertexElementFromAttribute(attributeName)
	assert(
		self:hasAttribute(attributeName),
		"attribute with name not in format"
	)
	return self.attributeToVertexElement[attributeName]
end

function GLTFAttributes:getAttributeFromVertexElement(vertexElementName)
	assert(
		self:hasVertexElement(vertexElementName),
		"vertex element with name not in format"
	)
	return self.vertexElementToAttribute[vertexElementName]
end

function GLTFAttributes:getLocationFromVertexElement(vertexElementName)
	assert(
		self:hasVertexElement(vertexElementName),
		"vertex element with name not in format"
	)
	return self.vertexElementToLocation[vertexElementName]
end

function GLTFAttributes:getVertexElementFromLocation(location)
	assert(self:hasLocation(location), "location with index not in format")
	return self.locationToVertexElement[location]
end

function GLTFAttributes:defineAttribute(
	attributeName,
	vertexElementName,
	location,
	format
)
	assert(
		self.attributeToVertexElement[attributeName] == nil,
		"duplicate attribute name"
	)
	assert(
		self.vertexElementToAttribute[vertexElementName] == nil,
		"duplicate vertex element name"
	)
	assert(self.locationToVertexElement[location] == nil, "duplicate location")

	self.attributeToVertexElement[attributeName] = vertexElementName
	self.vertexElementToAttribute[vertexElementName] = attributeName
	self.vertexElementToLocation[vertexElementName] = location
	self.locationToVertexElement[location] = vertexElementName

	table.insert(self.format, {
		location = location,
		name = vertexElementName,
		format = format,
	})
end

function GLTFAttributes:getFormat()
	return self.format
end

return GLTFAttributes
