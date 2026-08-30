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
--- @field private texture? love.Texture | love.ImageData
--- @field private normalTexture? love.Texture | love.ImageData
--- @field private occlusionTexture? love.Texture | love.ImageData
--- @field private metalRoughnessTexture? love.Texture | love.ImageData
--- @field private emissiveTexture? love.Texture | love.ImageData
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

--- @param r number
--- @param g number
--- @param b number
--- @param a number
function Material:setColor(r, g, b, a)
	Table.copy(self.color, 1, 4, r, g, b, a)
end

function Material:getRoughness()
	return self.roughness
end

--- @param value number
function Material:setRoughness(value)
	self.roughness = value
end

function Material:getMetal()
	return self.metal
end

--- @param value number
function Material:setMetal(value)
	self.metal = value
end

function Material:getOcclusion()
	return self.occlusion
end

--- @param value number
function Material:setOcclusion(value)
	self.occlusion = value
end

function Material:getNormalScale()
	return self.normalScale
end

--- @param value number
function Material:setNormalScale(value)
	self.normalScale = value
end

function Material:getEmissive()
	return Table.unpack(self.emissive, 1, 3)
end

--- @param r number
--- @param g number
--- @param b number
function Material:setEmissive(r, g, b)
	Table.copy(self.emissive, 1, 3, r, g, b)
end

function Material:getAlphaCutoff()
	return self.alphaCutoff
end

--- @param value number
function Material:setAlphaCutoff(value)
	self.alphaCutoff = value
end

function Material:getTexture()
	return self.texture
end

--- @param value love.Texture | love.ImageData
function Material:setTexture(value)
	self.texture = value
end

function Material:getNormalTexture()
	return self.normalTexture
end

--- @param value love.Texture | love.ImageData
function Material:setNormalTexture(value)
	self.normalTexture = value
end

function Material:getOcclusionTexture()
	return self.occlusionTexture
end

--- @param value love.Texture | love.ImageData
function Material:setOcclusionTexture(value)
	self.occlusionTexture = value
end

function Material:getMetalRoughnessTexture()
	return self.metalRoughnessTexture
end

--- @param value love.Texture | love.ImageData
function Material:setMetalRoughnessTexture(value)
	self.metalRoughnessTexture = value
end

function Material:getEmissiveTexture()
	return self.emissiveTexture
end

--- @param value love.Texture | love.ImageData
function Material:setEmissiveTexture(value)
	self.emissiveTexture = value
end

--- @param materialDefinition RatScratch.Graphics.Graphics3D.MaterialDefinition
function Material.fromDefinition(materialDefinition)
	local material = Material()

	if
		materialDefinition.texture and materialDefinition.texture.albedoFactor
	then
		material:setColor(
			Table.unpack(materialDefinition.texture.albedoFactor, 1, 4)
		)
	end

	if
		materialDefinition.normalTexture
		and materialDefinition.normalTexture.normalScale
	then
		material:setNormalScale(materialDefinition.normalTexture.normalScale)
	end

	if
		materialDefinition.occlusionTexture
		and materialDefinition.occlusionTexture.occlusionStrength
	then
		material:setOcclusion(
			materialDefinition.occlusionTexture.occlusionStrength
		)
	end

	if
		materialDefinition.metalRoughnessTexture
		and materialDefinition.metalRoughnessTexture.metalFactor
	then
		material:setMetal(materialDefinition.metalRoughnessTexture.metalFactor)
	end

	if
		materialDefinition.metalRoughnessTexture
		and materialDefinition.metalRoughnessTexture.roughnessFactor
	then
		material:setRoughness(
			materialDefinition.metalRoughnessTexture.roughnessFactor
		)
	end
	if
		materialDefinition.emissiveTexture
		and materialDefinition.emissiveTexture.emissiveFactor
	then
		material:setColor(
			Table.unpack(
				materialDefinition.emissiveTexture.emissiveFactor,
				1,
				3
			)
		)
	end

	if materialDefinition.alphaCutoff then
		material:setAlphaCutoff(materialDefinition.alphaCutoff)
	end

	if materialDefinition.texture and materialDefinition.texture.texture then
		material:setTexture(materialDefinition.texture.texture)
	end

	if
		materialDefinition.normalTexture
		and materialDefinition.normalTexture.texture
	then
		material:setNormalTexture(materialDefinition.normalTexture.texture)
	end

	if
		materialDefinition.occlusionTexture
		and materialDefinition.occlusionTexture.texture
	then
		material:setOcclusionTexture(
			materialDefinition.occlusionTexture.texture
		)
	end

	if
		materialDefinition.metalRoughnessTexture
		and materialDefinition.metalRoughnessTexture.texture
	then
		material:setMetalRoughnessTexture(
			materialDefinition.metalRoughnessTexture.texture
		)
	end

	if
		materialDefinition.emissiveTexture
		and materialDefinition.emissiveTexture.texture
	then
		material:setEmissiveTexture(materialDefinition.emissiveTexture.texture)
	end

	return material
end

return Material
