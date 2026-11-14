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

--- @class RatScratch.Pipeline.ForwardRenderPass : RatScratch.Pipeline.RenderPass
--- @field private renderBufferOverride? RatScratch.Pipeline.RenderBuffer.CanvasPointer[]
--- @field private renderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private oitRenderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private sortedCullResult RatScratch.Pipeline.SortedCullResult
--- @field private lightClusterResult RatScratch.Pipeline.LightClusterResult
--- @field private reflectionProbeClusterResult? RatScratch.Pipeline.ReflectionProbeClusterResult
--- @field private width integer
--- @field private height integer
--- @field private isOpaque boolean
--- @overload fun(): RatScratch.Pipeline.ForwardRenderPass
local ForwardRenderPass = Object(RenderPass)

ForwardRenderPass.A_BUFFER_FRAGMENT_FORMAT = {
	{ location = 0, name = "color", format = "uint32" },
	{ location = 1, name = "depth", format = "float" },
}

ForwardRenderPass.RENDER_BUFFER_FORMAT = {
	"srgba8",
}

ForwardRenderPass.OIT_RENDER_BUFFER_FORMAT = {
	"r8ui",
	"r32ui",
}

ForwardRenderPass.OIT_A_BUFFER_FRAGMENT_COUNT = 1
ForwardRenderPass.OIT_A_BUFFER_FRAGMENT_LOCK = 2

ForwardRenderPass.RENDER_BUFFER_DEPTH_FORMAT = "depth32f"

function ForwardRenderPass:new()
	RenderPass.new(self)

	self:addDependencyRequirement(ShadowRenderPass, "soft")
	self:addDependencyRequirement(ReflectionRenderPass, "soft")

	self.width, self.height = love.graphics.getDimensions()
	self.isRenderBufferDirty = true

	self.isOpaque = false
end

function ForwardRenderPass:getIsOpaque()
	return self.isOpaque
end

--- @param value boolean
function ForwardRenderPass:setIsOpaque(value)
	self.isOpaque = value
end

--- @param width integer
--- @param height integer
function ForwardRenderPass:resize(width, height)
	local w, h = math.max(width, 1), math.max(height, 1)
	if not (self.width == w and self.height == h) then
		self.width = w
		self.height = h
		self.isRenderBufferDirty = true
	end
end

function ForwardRenderPass:getWidth()
	return self.width
end

function ForwardRenderPass:getHeight()
	return self.height
end

function ForwardRenderPass:setRenderBufferOverride(...)
	self.renderBufferOverride = { ... }
end

function ForwardRenderPass:getRenderBufferOverride()
	return unpack(self.renderBufferOverride)
end

function ForwardRenderPass:hasRenderBufferOverride()
	return not not self.renderBufferOverride
end

--- @private
function ForwardRenderPass:_updateRenderBuffer()
	local cameraCount =
		self.sortedCullResult:getCamerasBuffer():getCameraCount()
	if
		self.isRenderBufferDirty
		or (self.renderBuffer and self.renderBuffer:getLayers() < cameraCount)
	then
		if not self:hasRenderBufferOverride() then
			if not self.renderBuffer then
				self.renderBuffer = RenderBuffer(
					ForwardRenderPass.RENDER_BUFFER_FORMAT,
					ForwardRenderPass.RENDER_BUFFER_DEPTH_FORMAT
				)
			end

			self.renderBuffer:resize(self.width, self.height, cameraCount)
		end
	end
end

--- @return RatScratch.Pipeline.RenderBuffer
function ForwardRenderPass:getRenderBuffer()
	assert(self:getIsAttached(), "cannot get render buffer until attached")
	assert(not self:hasRenderBufferOverride(), "render buffer is overriden")

	self:_updateRenderBuffer()
	return self.renderBuffer
end

function ForwardRenderPass:attached()
	RenderPass.attached(self)

	assert(
		self.sortedCullResult,
		"expected cull result to be set before being attached"
	)

	self.lightClusterResult =
		LightClusterResult(self.sortedCullResult:getCamerasBuffer())

	if self:hasDependency(ReflectionRenderPass) then
		self.reflectionProbeClusterResult = ReflectionProbeClusterResult(
			self.sortedCullResult:getCamerasBuffer()
		)
	end

	self.prepareOITShader = self:getPipelineRuntime():loadComputeShader(
		"@Pipeline/Base/Forward/PrepareOIT.compute.glsl",
		self:getQualityPreset()
	)

	self.resolveOITShader = self:getPipelineRuntime():loadShader(
		"@Pipeline/Base/Forward/ResolveOIT.frag.glsl",
		"@Pipeline/PostProcess/SubsetLayeredVertex.vert.glsl",
		self:getQualityPreset()
	)
end

function ForwardRenderPass:getCullResult()
	return self.sortedCullResult
end

--- @param value RatScratch.Pipeline.SortedCullResult
function ForwardRenderPass:setCullResult(value)
	assert(
		not self.sortedCullResult,
		"cull result already set; cannot change once set"
	)
	self.sortedCullResult = value
end

function ForwardRenderPass:getLightClusterResult()
	return self.lightClusterResult
end

function ForwardRenderPass:start()
	RenderPass.start(self)

	self:_updateRenderBuffer()

	self:getScene():getPipeline(LightPipeline):clusterLights(
		self:getQualityPreset(),
		self.renderBuffer:getWidth(),
		self.renderBuffer:getHeight(),
		self.lightClusterResult
	)

	if self.reflectionProbeClusterResult then
		self:getScene()
			:getPipeline(ReflectionProbePipeline)
			:clusterReflectionProbes(
				self:getQualityPreset(),
				self.renderBuffer:getWidth(),
				self.renderBuffer:getHeight(),
				self.reflectionProbeClusterResult
			)
	end
end

do
	local _screenSize = { 0, 0 }

	--- @private
	--- @param drawShader love.Shader
	--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
	function ForwardRenderPass:_bindDrawShader(drawShader, pipelineRenderer)
		pipelineRenderer:bind(drawShader, self)

		self.sortedCullResult:getCamerasBuffer():bind(drawShader)

		if drawShader:hasUniform("rat_DrawsBuffer") then
			drawShader:send(
				"rat_DrawsBuffer",
				self.sortedCullResult:getDrawsBuffer()
			)
		end

		if drawShader:hasUniform("rat_LightCountIndicesBuffer") then
			drawShader:send(
				"rat_LightCountIndicesBuffer",
				self.lightClusterResult:getLightIndicesBuffer()
			)
		end

		local screenSize = _screenSize
		screenSize[1], screenSize[2] =
			self.renderBuffer:getWidth(), self.renderBuffer:getHeight()
		if drawShader:hasUniform("rat_ScreenSize") then
			drawShader:send("rat_ScreenSize", screenSize)
		end

		if self:hasDependency(ShadowRenderPass) then
			self:getDependency(ShadowRenderPass):bind(drawShader)
		end

		if self:hasDependency(ReflectionRenderPass) then
			self:getDependency(ReflectionRenderPass):bind(drawShader)
		else
			if drawShader:hasUniform("rat_ReflectionProbeCount") then
				drawShader:send("rat_ReflectionProbeCount", 0)
			end
		end

		if self.reflectionProbeClusterResult then
			if
				drawShader:hasUniform("rat_ReflectionProbeCountIndicesBuffer")
			then
				drawShader:send(
					"rat_ReflectionProbeCountIndicesBuffer",
					self.reflectionProbeClusterResult:getReflectionProbeIndicesBuffer()
				)
			end
		end
	end
end

--- @private
--- @param drawShader love.Shader
function ForwardRenderPass:_drawForward(drawShader)
	love.graphics.push("all")
	love.graphics.setShader(drawShader)

	local writeDepth = self:getIsOpaque()
	love.graphics.setDepthMode("lequal", writeDepth)

	if self:hasRenderBufferOverride() then
		RenderBuffer.multibind(unpack(self.renderBufferOverride))
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
function ForwardRenderPass:draw(pipelineRenderer)
	local material = self:getWorld():getPipeline(MaterialPipeline)
	local drawShaderResource =
		material:getShader(self:getQualityPreset(), "forward", "opaque", "draw")

	if not drawShaderResource:getIsReady() then
		return
	end

	local drawShader = drawShaderResource:get()
	self:_bindDrawShader(drawShader, pipelineRenderer)
	self:_drawForward(drawShader)
end

return ForwardRenderPass
