local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.RenderPass : RatScratch.Common.BaseObject
--- @field private isReady boolean
--- @field private quality string
--- @field private world RatScratch.Pipeline.World
--- @field private scene RatScratch.Pipeline.Scene
--- @overload fun(): RatScratch.Pipeline.RenderPass
local RenderPass = Object()

function RenderPass:new()
	self.isReady = false
end

--- @param quality string
--- @param world RatScratch.Pipeline.World
--- @param scene RatScratch.Pipeline.Scene
function RenderPass:attach(quality, world, scene)
	assert(not self.isReady, "render pass was already attached")

	self.quality = quality
	self.world = world
	self.scene = scene

	self.isReady = true
	self:attached()
end

--- @protected
function RenderPass:attached()
	-- Nothing.
end

function RenderPass:getIsAttached()
	return self.isReady
end

function RenderPass:getQualityPreset()
	assert(self.isReady, "render pass was not attached")
	return self.quality
end

--- @return RatScratch.Pipeline.World
function RenderPass:getWorld()
	assert(self.isReady, "render pass was not attached")
	return self.world
end

--- @return RatScratch.Pipeline.Scene
function RenderPass:getScene()
	assert(self.isReady, "render pass was not attached")
	return self.scene
end

return RenderPass
