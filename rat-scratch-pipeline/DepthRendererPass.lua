local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local LightClusterResult = require("rat-scratch-pipeline.LightClusterResult")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local ReflectionProbeClusterResult =
	require("rat-scratch-pipeline.ReflectionProbeClusterResult")
local ReflectionProbePipeline =
	require("rat-scratch-pipeline.ReflectionProbePipeline")
local ReflectionRenderPass =
	require("rat-scratch-pipeline.ReflectionRenderPass")
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")
local RenderPass = require("rat-scratch-pipeline.RenderPass")
local ShadowRenderPass = require("rat-scratch-pipeline.ShadowRenderPass")

--- @class RatScratch.Pipeline.DepthRenderPass : RatScratch.Pipeline.RenderPass
--- @field private renderBufferOverride? RatScratch.Pipeline.RenderBuffer.CanvasPointer[]
--- @field private renderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private oitRenderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private sortedCullResult RatScratch.Pipeline.SortedCullResult
--- @field private lightClusterResult RatScratch.Pipeline.LightClusterResult
--- @field private reflectionProbeClusterResult? RatScratch.Pipeline.ReflectionProbeClusterResult
--- @field private width integer
--- @field private height integer
--- @field private isOpaque boolean
--- @overload fun(): RatScratch.Pipeline.DepthRenderPass
local DepthRenderPass = Object(RenderPass)

DepthRenderPass.RENDER_BUFFER_DEPTH_FORMAT = "depth32f"

function DepthRenderPass:new()
	RenderPass.new(self)

	self.width, self.height = love.graphics.getDimensions()
	self.isRenderBufferDirty = true

	self.isOpaque = true
end

--- @param value boolean
function DepthRenderPass:setIsOpaque(value)
	self.isOpaque = value
end

function DepthRenderPass:getIsOpaque()
	return self.isOpaque
end

--- @param value boolean
function DepthRenderPass:setIsMask(value)
	self.isOpaque = not value
end

function DepthRenderPass:getIsMask()
	return not self.isOpaque
end

--- @param width integer
--- @param height integer
function DepthRenderPass:resize(width, height)
	local w, h = math.max(width, 1), math.max(height, 1)
	if not (self.width == w and self.height == h) then
		self.width = w
		self.height = h
		self.isRenderBufferDirty = true
	end
end

function DepthRenderPass:getWidth()
	return self.width
end

function DepthRenderPass:getHeight()
	return self.height
end

function DepthRenderPass:setRenderBufferOverride(...)
	self.renderBufferOverride = { ... }
end

function DepthRenderPass:getRenderBufferOverride()
	return unpack(self.renderBufferOverride)
end

function DepthRenderPass:hasRenderBufferOverride()
	return not not self.renderBufferOverride
end

--- @private
function DepthRenderPass:_updateRenderBuffer()
	local cameraCount =
		self.sortedCullResult:getCamerasBuffer():getCameraCount()
	if
		self.isRenderBufferDirty
		or (self.renderBuffer and self.renderBuffer:getLayers() < cameraCount)
	then
		if not self:hasRenderBufferOverride() then
			if not self.renderBuffer then
				self.renderBuffer =
					RenderBuffer({}, DepthRenderPass.RENDER_BUFFER_DEPTH_FORMAT)
			end

			self.renderBuffer:resize(self.width, self.height, cameraCount)
		end

		self.isRenderBufferDirty = false
	end
end

--- @return RatScratch.Pipeline.RenderBuffer
function DepthRenderPass:getRenderBuffer()
	assert(self:getIsAttached(), "cannot get render buffer until attached")
	assert(not self:hasRenderBufferOverride(), "render buffer is overriden")

	self:_updateRenderBuffer()
	return self.renderBuffer
end

function DepthRenderPass:attached()
	RenderPass.attached(self)

	assert(
		self.sortedCullResult,
		"expected cull result to be set before being attached"
	)
end

function DepthRenderPass:getCullResult()
	return self.sortedCullResult
end

--- @param value RatScratch.Pipeline.SortedCullResult
function DepthRenderPass:setCullResult(value)
	assert(
		not self.sortedCullResult,
		"cull result already set; cannot change once set"
	)
	self.sortedCullResult = value
end

function DepthRenderPass:start()
	RenderPass.start(self)

	self:_updateRenderBuffer()
end

--- @private
--- @param drawShader love.Shader
--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
function DepthRenderPass:_bindDrawShader(drawShader, pipelineRenderer)
	pipelineRenderer:bind(drawShader, self)

	self.sortedCullResult:getCamerasBuffer():bind(drawShader)

	if drawShader:hasUniform("rat_DrawsBuffer") then
		drawShader:send(
			"rat_DrawsBuffer",
			self.sortedCullResult:getDrawsBuffer()
		)
	end
end

--- @private
--- @param drawShader love.Shader
function DepthRenderPass:_drawDepth(drawShader)
	love.graphics.push("all")
	love.graphics.setShader(drawShader)

	love.graphics.setDepthMode("lequal", true)

	if self:hasRenderBufferOverride() then
		RenderBuffer.multibindDepth(unpack(self.renderBufferOverride))
	else
		self:getRenderBuffer():bind()
		love.graphics.clear(0, 0, 0, 0)
	end

	love.graphics.drawFromShaderIndirect(
		"triangles",
		self.sortedCullResult:getIndirectDrawBuffer()
	)

	love.graphics.pop()
end

--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
function DepthRenderPass:draw(pipelineRenderer)
	local material = self:getWorld():getPipeline(MaterialPipeline)
	local drawShaderResource = material:getShader(
		self:getQualityPreset(),
		"depth",
		self:getIsOpaque() and "opaque" or "mask",
		"draw"
	)

	if not drawShaderResource:getIsReady() then
		return
	end

	local drawShader = drawShaderResource:get()
	self:_bindDrawShader(drawShader, pipelineRenderer)
	self:_drawDepth(drawShader)
end

return DepthRenderPass
