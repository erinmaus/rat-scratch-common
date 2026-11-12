local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local LightClusterResult = require("rat-scratch-pipeline.LightClusterResult")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local PostProcess = require("rat-scratch-pipeline.PostProcess")
local ReflectionProbeClusterResult =
	require("rat-scratch-pipeline.ReflectionProbeClusterResult")
local ReflectionProbePipeline =
	require("rat-scratch-pipeline.ReflectionProbePipeline")
local ReflectionRenderPass =
	require("rat-scratch-pipeline.ReflectionRenderPass")
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")
local RenderPass = require("rat-scratch-pipeline.RenderPass")
local ShadowRenderPass = require("rat-scratch-pipeline.ShadowRenderPass")

--- @class RatScratch.Pipeline.OITForwardRenderPass : RatScratch.Pipeline.RenderPass
--- @field private renderBufferOverride? RatScratch.Pipeline.RenderBuffer.CanvasPointer[]
--- @field private renderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private oitRenderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private sortedCullResult RatScratch.Pipeline.SortedCullResult
--- @field private lightClusterResult RatScratch.Pipeline.LightClusterResult
--- @field private reflectionProbeClusterResult? RatScratch.Pipeline.ReflectionProbeClusterResult
--- @field private width integer
--- @field private height integer
--- @field private prepareOITShader RatScratch.Resource.Resource<love.Shader>
--- @field private resolveOITShader RatScratch.Resource.Resource<love.Shader>
--- @field private aBuffer love.GraphicsBuffer
--- @overload fun(): RatScratch.Pipeline.OITForwardRenderPass
local OITForwardRenderPass = Object(RenderPass)

OITForwardRenderPass.A_BUFFER_FRAGMENT_FORMAT = {
	{ location = 0, name = "color", format = "uint32" },
	{ location = 1, name = "depth", format = "float" },
}

OITForwardRenderPass.RENDER_BUFFER_FORMAT = {
	"srgba8",
}

OITForwardRenderPass.OIT_RENDER_BUFFER_FORMAT = {
	"r8ui",
	"r32ui",
}

OITForwardRenderPass.OIT_A_BUFFER_FRAGMENT_COUNT = 1
OITForwardRenderPass.OIT_A_BUFFER_FRAGMENT_LOCK = 2

OITForwardRenderPass.RENDER_BUFFER_DEPTH_FORMAT = "depth32f"

function OITForwardRenderPass:new()
	RenderPass.new(self)

	self:addDependencyRequirement(ShadowRenderPass, "soft")
	self:addDependencyRequirement(ReflectionRenderPass, "soft")

	self.width, self.height = love.graphics.getDimensions()
	self.isRenderBufferDirty = true
end

--- @param width integer
--- @param height integer
function OITForwardRenderPass:resize(width, height)
	local w, h = math.max(width, 1), math.max(height, 1)
	if not (self.width == w and self.height == h) then
		self.width = w
		self.height = h
		self.isRenderBufferDirty = true
	end
end

function OITForwardRenderPass:getWidth()
	return self.width
end

function OITForwardRenderPass:getHeight()
	return self.height
end

function OITForwardRenderPass:setRenderBufferOverride(...)
	self.renderBufferOverride = { ... }
end

function OITForwardRenderPass:getRenderBufferOverride()
	return unpack(self.renderBufferOverride)
end

function OITForwardRenderPass:hasRenderBufferOverride()
	return not not self.renderBufferOverride
end

--- @private
function OITForwardRenderPass:_updateRenderBuffer()
	local cameraCount =
		self.sortedCullResult:getCamerasBuffer():getCameraCount()
	if
		self.isRenderBufferDirty
		or (self.renderBuffer and self.renderBuffer:getLayers() < cameraCount)
	then
		if not self:hasRenderBufferOverride() then
			if not self.renderBuffer then
				self.renderBuffer = RenderBuffer(
					OITForwardRenderPass.RENDER_BUFFER_FORMAT,
					OITForwardRenderPass.RENDER_BUFFER_DEPTH_FORMAT
				)
			end

			self.renderBuffer:resize(self.width, self.height, cameraCount)
		end

		if not self.oitRenderBuffer then
			self.oitRenderBuffer =
				RenderBuffer(OITForwardRenderPass.OIT_RENDER_BUFFER_FORMAT)
		end

		self.oitRenderBuffer:resize(self.width, self.height, cameraCount)

		if self.aBuffer then
			self.aBuffer:release()
		end

		local oitSamples = self:getPipelineRuntime():getCurrentProperty(
			self:getQualityPreset(),
			"pipeline.properties.forward.oitSampleCount"
		)

		local count = self.width * self.height * cameraCount * oitSamples
		self.aBuffer = love.graphics.newBuffer(
			OITForwardRenderPass.A_BUFFER_FRAGMENT_FORMAT,
			count,
			{ shaderstorage = true }
		)

		self.isRenderBufferDirty = false
	end
end

--- @return RatScratch.Pipeline.RenderBuffer
function OITForwardRenderPass:getRenderBuffer()
	assert(self:getIsAttached(), "cannot get render buffer until attached")
	assert(not self:hasRenderBufferOverride(), "render buffer is overriden")

	return self.renderBuffer
end

function OITForwardRenderPass:attached()
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

function OITForwardRenderPass:getCullResult()
	return self.sortedCullResult
end

--- @param value RatScratch.Pipeline.SortedCullResult
function OITForwardRenderPass:setCullResult(value)
	assert(
		not self.sortedCullResult,
		"cull result already set; cannot change once set"
	)
	self.sortedCullResult = value
end

function OITForwardRenderPass:getLightClusterResult()
	return self.lightClusterResult
end

function OITForwardRenderPass:start()
	RenderPass.start(self)

	self:_updateRenderBuffer()

	self:getScene():getPipeline(LightPipeline):clusterLights(
		self:getQualityPreset(),
		self.width,
		self.height,
		self.lightClusterResult
	)

	if self.reflectionProbeClusterResult then
		self:getScene()
			:getPipeline(ReflectionProbePipeline)
			:clusterReflectionProbes(
				self:getQualityPreset(),
				self.width,
				self.height,
				self.reflectionProbeClusterResult
			)
	end
end

do
	local _screenSize = { 0, 0 }

	--- @private
	--- @param drawShader love.Shader
	--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
	function OITForwardRenderPass:_bindDrawShader(drawShader, pipelineRenderer)
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
		screenSize[1], screenSize[2] = self.width, self.height
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

		if drawShader:hasUniform("rat_OITABufferCount") then
			drawShader:send(
				"rat_OITABufferCount",
				self.oitRenderBuffer:getCanvas(
					OITForwardRenderPass.OIT_A_BUFFER_FRAGMENT_COUNT
				)
			)
		end

		if drawShader:hasUniform("rat_OITABufferFragmentLock") then
			drawShader:send(
				"rat_OITABufferFragmentLock",
				self.oitRenderBuffer:getCanvas(
					OITForwardRenderPass.OIT_A_BUFFER_FRAGMENT_COUNT
				)
			)
		end

		if drawShader:hasUniform("rat_OITFragmentsBuffer") then
			drawShader:send("rat_OITFragmentsBuffer", self.aBuffer)
		end
	end
end

--- @private
--- @param drawShader love.Shader
function OITForwardRenderPass:_drawForward(drawShader)
	love.graphics.push("all")
	love.graphics.setShader(drawShader)
	love.graphics.setDepthMode("lequal", false)

	if drawShader:hasUniform("rat_OITABufferLock") then
		drawShader:send(
			"rat_OITABufferLock",
			self.oitRenderBuffer:getCanvas(
				OITForwardRenderPass.OIT_A_BUFFER_FRAGMENT_LOCK
			)
		)
	end

	if self:hasRenderBufferOverride() then
		RenderBuffer.multibindDepth(unpack(self.renderBufferOverride))
	else
		self:getRenderBuffer():bind(nil, true)
		love.graphics.clear(0, 0, 0, 0)
	end

	love.graphics.drawFromShaderIndirect(
		"triangles",
		self.sortedCullResult:getIndirectDrawBuffer()
	)

	love.graphics.pop()
end

function OITForwardRenderPass:_prepareOIT()
	if not self.prepareOITShader:getIsReady() then
		return
	end

	local shader = self.prepareOITShader:get()

	local camerasBuffer = self.sortedCullResult:getCamerasBuffer()
	local activeCameraBuffer = camerasBuffer:getActiveCameraBuffer()
	if shader:hasUniform("rat_LayersBuffer") then
		shader:send("rat_LayersBuffer", activeCameraBuffer:getBuffer())
	end

	if shader:hasUniform("rat_OITABufferCount") then
		shader:send(
			"rat_OITABufferCount",
			self.oitRenderBuffer:getCanvas(
				OITForwardRenderPass.OIT_A_BUFFER_FRAGMENT_COUNT
			)
		)
	end

	local localX, localY = shader:getLocalThreadgroupSize()

	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(self.width / localX), 1),
		math.max(math.ceil(self.height / localY), 1),
		1
	)
end

--- @private
function OITForwardRenderPass:_resolveOIT()
	if not self.resolveOITShader:getIsReady() then
		return
	end

	love.graphics.push("all")
	love.graphics.setBlendMode("alpha")
	love.graphics.setDepthMode()

	local shader = self.resolveOITShader:get()
	love.graphics.setShader(shader)

	if self:hasRenderBufferOverride() then
		RenderBuffer.multibind(unpack(self.renderBufferOverride))
	else
		self:getRenderBuffer():bind()
		love.graphics.clear(0, 0, 0, 0)
	end

	local camerasBuffer = self.sortedCullResult:getCamerasBuffer()
	local activeCameraBuffer = camerasBuffer:getActiveCameraBuffer()
	if shader:hasUniform("rat_LayersBuffer") then
		shader:send("rat_LayersBuffer", activeCameraBuffer:getBuffer())
	end

	if shader:hasUniform("rat_OITABufferCount") then
		shader:send(
			"rat_OITABufferCount",
			self.oitRenderBuffer:getCanvas(
				OITForwardRenderPass.OIT_A_BUFFER_FRAGMENT_COUNT
			)
		)
	end

	if shader:hasUniform("rat_OITFragmentsBuffer") then
		shader:send("rat_OITFragmentsBuffer", self.aBuffer)
	end

	local activeCameraCount = camerasBuffer:getActiveCameraCount()
	PostProcess.drawInstanced(activeCameraCount)
	love.graphics.pop()
end

--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
function OITForwardRenderPass:draw(pipelineRenderer)
	local material = self:getWorld():getPipeline(MaterialPipeline)
	local drawShaderResource =
		material:getShader(self:getQualityPreset(), "forward", "blend", "draw")

	if not drawShaderResource:getIsReady() then
		return
	end

	self:_prepareOIT()

	local drawShader = drawShaderResource:get()
	self:_bindDrawShader(drawShader, pipelineRenderer)
	self:_drawForward(drawShader)

	self:_resolveOIT()
end

return OITForwardRenderPass
