local Object = require("rat-scratch-common").Object

--- @class RatScratch.GLTF.GLTFAttributes : RatScratch.Common.BaseObject
--- @field private attributeToVertexElement table<string, string>
--- @field private vertexElementToAttribute table<string, string>
--- @field private locationToVertexElement table<number, string>
--- @field private vertexElementToLocation table<string, number>
--- @field private format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
local GLTFAttributes = Object()

function GLTFAttributes:new()
    self.attributeToVertexElement = {}
    self.vertexElementToAttribute = {}
    self.locationToVertexElement = {}
    self.vertexElementToLocation = {}
    self.format = {}

    self:defineAttribute("POSITION", "VertexPosition", 0, "floatvec4")
    self:defineAttribute("TEXCOORD_0", "VertexTexCoord", 1, "floatvec4")
    self:defineAttribute("COLOR_0", "VertexColor", 2, "floatvec4")
    self:defineAttribute("NORMAL", "VertexNormal", 10, "floatvec4")
    self:defineAttribute("JOINTS_0", "VertexBoneIndex", 20, "uint32vec4")
    self:defineAttribute("WEIGHTS_0", "VertexBoneWeight", 21, "floatvec4")
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
    assert(self:hasAttribute(attributeName), "attribute with name not in format")
    return self.attributeToVertexElement[attributeName]
end

function GLTFAttributes:getAttributeFromVertexElement(vertexElementName)
    assert(self:hasVertexElement(vertexElementName), "vertex element with name not in format")
    return self.vertexElementToAttribute[vertexElementName]
end

function GLTFAttributes:getLocationFromVertexElement(vertexElementName)
    assert(self:hasVertexElement(vertexElementName), "vertex element with name not in format")
    return self.vertexElementToLocation[vertexElementName]
end

function GLTFAttributes:getVertexElementFromLocation(location)
    assert(self:hasLocation(location), "location with index not in format")
    return self.locationToVertexElement[location]
end

function GLTFAttributes:defineAttribute(attributeName, vertexElementName, location, format)
    assert(self.attributeToVertexElement[attributeName] == nil, "duplicate attribute name")
    assert(self.vertexElementToAttribute[vertexElementName] == nil, "duplicate vertex element name")
    assert(self.locationToVertexElement[location] == nil, "duplicate location")

    self.attributeToVertexElement[attributeName] = vertexElementName
    self.vertexElementToAttribute[vertexElementName] = attributeName
    self.vertexElementToLocation[vertexElementName] = location
    self.locationToVertexElement[location] = vertexElementName

    table.insert(self.format, {
        location = location,
        name = vertexElementName,
        format = format
    })
end

function GLTFAttributes:getFormat()
    return self.format
end

return GLTFAttributes
