local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local LightClusterResult = require("rat-scratch-pipeline.LightClusterResult")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")
local RenderPass = require("rat-scratch-pipeline.RenderPass")
local ShadowRenderPass = require("rat-scratch-pipeline.ShadowRenderPass")

--- @class RatScratch.Pipeline.ForwardRenderPass : RatScratch.Pipeline.RenderPass
--- @field private renderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private cullResult RatScratch.Pipeline.CullResult
--- @field private lightClusterResult RatScratch.Pipeline.LightClusterResult
--- @field private width integer
--- @field private height integer
--- @overload fun(): RatScratch.Pipeline.ForwardRenderPass
local ForwardRenderPass = Object(RenderPass)

ForwardRenderPass.RENDER_BUFFER_FORMAT = {
	"srgba8",
}

ForwardRenderPass.RENDER_BUFFER_DEPTH_FORMAT = "depth32f"

function ForwardRenderPass:new()
	RenderPass.new(self)

	self:addDependencyRequirement(ShadowRenderPass, "soft")

	self.width, self.height = love.graphics.getDimensions()
	self.isRenderBufferDirty = true
end

--- @param width integer
--- @param height integer
function ForwardRenderPass:resize(width, height)
	local w, h = math.max(width, 1), math.max(height, 1)
	if not (self.width == w and self.height == h) then
		self.width = w
		self.width = h
		self.isRenderBufferDirty = true
	end
end

function ForwardRenderPass:getWidth()
	return self.width
end

function ForwardRenderPass:getHeight()
	return self.height
end

--- @private
function ForwardRenderPass:_updateRenderBuffer()
	local _, cameraCount = self.cullResult:getCamerasBuffer():getCameraCount()
	if
		self.isRenderBufferDirty
		or (self.renderBuffer and self.renderBuffer:getLayers() ~= cameraCount)
	then
		if not self.renderBuffer then
			self.renderBuffer = RenderBuffer(
				ForwardRenderPass.RENDER_BUFFER_FORMAT,
				ForwardRenderPass.RENDER_BUFFER_DEPTH_FORMAT
			)
		end

		self.renderBuffer:resize(self.width, self.height, cameraCount)
	end
end

--- @return RatScratch.Pipeline.RenderBuffer
function ForwardRenderPass:getRenderBuffer()
	assert(self:getIsAttached(), "cannot get render buffer until attached")
	return self.renderBuffer
end

function ForwardRenderPass:attached()
	RenderPass.attached(self)

	if not self.cullResult then
		self.cullResult = self:getScene():newCullResult()
	end

	self.lightClusterResult =
		LightClusterResult(self.cullResult:getCamerasBuffer())
end

function ForwardRenderPass:getCullResult()
	return self.cullResult
end

--- @param value RatScratch.Pipeline.CullResult
function ForwardRenderPass:setCullResult(value)
	assert(
		not self.cullResult,
		"cull result already set; cannot change once set"
	)
	self.cullResult = value
end

function ForwardRenderPass:getLightClusterResult()
	return self.lightClusterResult
end

function ForwardRenderPass:start()
	self:_updateRenderBuffer()

	self:getScene()
		:getPipeline(LightPipeline)
		:clusterLights(self:getQualityPreset(), self.lightClusterResult)
end

function ForwardRenderPass:bind(shader)
	self.cullResult:getCamerasBuffer():bind(shader)

	if shader:hasUniform("rat_DrawsBuffer") then
		shader:send("rat_DrawsBuffer", self.cullResult:getDrawsBuffer())
	end

	if shader:hasUniform("rat_LightCountIndicesBuffer") then
		shader:send(
			"rat_LightCountIndicesBuffer",
			self.lightClusterResult:getLightIndicesBuffer()
		)
	end
end

return ForwardRenderPass
