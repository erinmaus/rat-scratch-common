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
--- @field private renderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private cullResult RatScratch.Pipeline.CullResult
--- @field private lightClusterResult RatScratch.Pipeline.LightClusterResult
--- @field private reflectionProbeClusterResult? RatScratch.Pipeline.ReflectionProbeClusterResult
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
	self:addDependencyRequirement(ReflectionRenderPass, "soft")

	self.width, self.height = love.graphics.getDimensions()
	self.isRenderBufferDirty = true
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

--- @private
function ForwardRenderPass:_updateRenderBuffer()
	local cameraCount = self.cullResult:getCamerasBuffer():getCameraCount()
	if
		self.isRenderBufferDirty
		or (self.renderBuffer and self.renderBuffer:getLayers() < cameraCount)
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

	if self:hasDependency(ReflectionRenderPass) then
		self.reflectionProbeClusterResult =
			ReflectionProbeClusterResult(self.cullResult:getCamerasBuffer())
	end
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

		self.cullResult:getCamerasBuffer():bind(drawShader)

		if drawShader:hasUniform("rat_DrawsBuffer") then
			drawShader:send("rat_DrawsBuffer", self.cullResult:getDrawsBuffer())
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
		drawShader:send("rat_ScreenSize", screenSize)

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
	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.setShader(drawShader)

	self:getRenderBuffer():bind()
	love.graphics.clear(0, 0, 0, 0)

	love.graphics.drawFromShaderIndirect(
		"triangles",
		self.cullResult:getIndirectBuffer()
	)
end

--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
function ForwardRenderPass:draw(pipelineRenderer)
	local material = self:getWorld():getPipeline(MaterialPipeline)
	local drawShaderResource =
		material:getShader(self:getQualityPreset(), "forward", "draw")

	if not drawShaderResource:getIsReady() then
		return
	end

	local drawShader = drawShaderResource:get()
	self:_bindDrawShader(drawShader, pipelineRenderer)
	self:_drawForward(drawShader)

	-- TODO: OIT
end

return ForwardRenderPass
