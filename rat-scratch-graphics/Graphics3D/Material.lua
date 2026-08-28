local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table

--- @class RatScratch.Graphics.Graphics3D.Material : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Graphics.Graphics3D.Material
--- @field private color number[]
--- @field private roughness number
--- @field private metal number
--- @field private occlusion number
--- @field private normalScale number
--- @field private emissive number[]
--- @field private alphaCutoff number
--- @field private texture? love.Texture
--- @field private normalTexture? love.Texture
--- @field private occlusionTexture? love.Texture
--- @field private metalRoughnessTexture? love.Texture
--- @field private emissiveTexture? love.Texture
local Material = Object()

function Material:new()
	self.color = { 1, 1, 1, 1 }
	self.roughness = 1
	self.metal = 1
	self.occlusion = 1
	self.normalScale = 1
	self.emissive = { 0, 0, 0 }
	self.alphaCutoff = 0.5
end

function Material:getColor()
	return Table.unpack(self.color, 1, 4)
end

function Material:setColor(r, g, b, a)
	Table.copy(self.color, 1, 4, r, g, b, a)
end

function Material:getRoughness()
	return self.roughness
end

function Material:setRoughness(value)
	self.roughness = value
end

function Material:getMetal()
	return self.metal
end

function Material:setMetal(value)
	self.metal = value
end

function Material:getOcclusion()
	return self.occlusion
end

function Material:setOcclusion(value)
	self.occlusion = value
end

function Material:getNormalScale()
	return self.normalScale
end

function Material:setNormalScale(value)
	self.normalScale = value
end

function Material:getEmissive()
	return Table.unpack(self.emissive, 1, 3)
end

function Material:setEmissive(r, g, b)
	Table.copy(self.emissive, 1, 3, r, g, b)
end

function Material:getAlphaCutoff()
	return self.alphaCutoff
end

function Material:setAlphaCutoff(value)
	self.alphaCutoff = value
end

function Material:getTexture()
	return self.texture
end

function Material:setTexture(value)
	self.texture = value
end

function Material:getNormalTexture()
	return self.normalTexture
end

function Material:setNormalTexture(value)
	self.normalTexture = value
end

function Material:getOcclusionTexture()
	return self.occlusionTexture
end

function Material:setOcclusionTexture(value)
	self.occlusionTexture = value
end

function Material:getMetalRoughnessTexture()
	return self.metalRoughnessTexture
end

function Material:setMetalRoughnessTexture(value)
	self.metalRoughnessTexture = value
end

function Material:getEmissiveTexture()
	return self.emissiveTexture
end

function Material:setEmissiveTexture(value)
	self.emissiveTexture = value
end

return Material
