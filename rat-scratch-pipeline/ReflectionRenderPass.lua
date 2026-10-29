local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local DoubleBufferResult = require("rat-scratch-pipeline.DoubleBufferResult")
local HiZResult = require("rat-scratch-pipeline.HiZResult")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local PostProcess = require("rat-scratch-pipeline.PostProcess")
local ReflectionProbePipeline =
	require("rat-scratch-pipeline.ReflectionProbePipeline")
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")
local RenderPass = require("rat-scratch-pipeline.RenderPass")
local ShadowRenderPass = require("rat-scratch-pipeline.ShadowRenderPass")

--- @class RatScratch.Pipeline.ReflectionRenderPass : RatScratch.Pipeline.RenderPass
--- @field private renderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private sourceRenderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private otherRenderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private cullResult RatScratch.Pipeline.CullResult
--- @field private lightClusterResult RatScratch.Pipeline.LightClusterResult
--- @field private blurDoubleBufferResult RatScratch.Pipeline.DoubleBufferResult
--- @field private hiZResult RatScratch.Pipeline.HiZResult
--- @overload fun(): RatScratch.Pipeline.ReflectionRenderPass
local ReflectionRenderPass = Object(RenderPass)

ReflectionRenderPass.RENDER_BUFFER_FORMAT = {
	"srgba8",
}

ReflectionRenderPass.RENDER_BUFFER_DEPTH_FORMAT = "depth32f"

ReflectionRenderPass.NIL_TEXTURE =
	love.graphics.newTexture(1, 1, 1, { canvas = true, readable = true })

function ReflectionRenderPass:new()
	RenderPass.new(self)

	self:addDependencyRequirement(ShadowRenderPass, "soft")

	self.renderBuffer = RenderBuffer(
		ReflectionRenderPass.RENDER_BUFFER_FORMAT,
		ReflectionRenderPass.RENDER_BUFFER_DEPTH_FORMAT
	)
	self.sourceRenderBuffer = RenderBuffer(
		ReflectionRenderPass.RENDER_BUFFER_FORMAT,
		ReflectionRenderPass.RENDER_BUFFER_DEPTH_FORMAT
	)
	self.otherRenderBuffer = RenderBuffer(
		ReflectionRenderPass.RENDER_BUFFER_FORMAT,
		ReflectionRenderPass.RENDER_BUFFER_DEPTH_FORMAT
	)
	self.blurDoubleBufferResult = DoubleBufferResult(
		self.sourceRenderBuffer,
		self.otherRenderBuffer,
		1,
		self.renderBuffer
	)
end

--- @private
function ReflectionRenderPass:_updateRenderBuffer()
	local cameraCount = self.cullResult:getCamerasBuffer():getCameraCount()

	local width, height = self:getPipelineRuntime():getCurrentProperty(
		self:getQualityPreset(),
		"pipeline.properties.reflection.sizeInPixels"
	)

	self.renderBuffer:resize(width, height, cameraCount)
	self.sourceRenderBuffer:resize(width, height, cameraCount)
	self.otherRenderBuffer:resize(width, height, cameraCount)
end

--- @return RatScratch.Pipeline.RenderBuffer
function ReflectionRenderPass:getRenderBuffer()
	assert(self:getIsAttached(), "cannot get render buffer until attached")
	return self.renderBuffer
end

function ReflectionRenderPass:attached()
	RenderPass.attached(self)

	if not self.cullResult then
		self.cullResult =
			self:getScene():getPipeline(ReflectionProbePipeline):newCullResult()
	end

	self.hiZResult =
		HiZResult(self.cullResult:getCamerasBuffer(), self.renderBuffer)

	if not self.lightClusterResult then
		self.lightClusterResult = self:getScene()
			:getPipeline(ReflectionProbePipeline)
			:newLightClusterResult()
	end

	self.blurShaderResource = self:getPipelineRuntime():loadShader(
		"@Pipeline/Base/Reflection/Blur.frag.glsl",
		"@Pipeline/PostProcess/SubsetLayeredVertex.vert.glsl",
		self:getQualityPreset()
	)
end

function ReflectionRenderPass:getCullResult()
	return self.cullResult
end

--- @param value RatScratch.Pipeline.CullResult
function ReflectionRenderPass:setCullResult(value)
	assert(
		not self.cullResult,
		"cull result already set; cannot change once set"
	)
	self.cullResult = value
end

function ReflectionRenderPass:getLightClusterResult()
	return self.lightClusterResult
end

--- @param shader love.Shader
function ReflectionRenderPass:bind(shader)
	if shader:hasUniform("rat_PipelineGlobalIlluminationAtlasView") then
		shader:send(
			"rat_PipelineGlobalIlluminationAtlasView",
			self.blurDoubleBufferResult:getResult()
		)
	end

	if shader:hasUniform("rat_PipelineReflectionAtlasView") then
		shader:send(
			"rat_PipelineReflectionAtlasView",
			self.renderBuffer:getCanvas(1)
		)
	end

	if shader:hasUniform("rat_PipelineReflectionMinMaxHiZAtlasView") then
		shader:send(
			"rat_PipelineReflectionMinMaxHiZAtlasView",
			self.hiZResult:getDestinationRenderBuffer():getCanvas(1)
		)
	end

	if shader:hasUniform("rat_ReflectionProbeCount") then
		shader:send(
			"rat_ReflectionProbeCount",
			self:getScene():getPipeline(ReflectionProbePipeline):getProbeCount()
		)
	end

	if shader:hasUniform("rat_ReflectionProbeCamerasBuffer") then
		shader:send(
			"rat_ReflectionProbeCamerasBuffer",
			self.cullResult:getCamerasBuffer():getCameraBuffer():getBuffer()
		)
	end
end

function ReflectionRenderPass:start()
	RenderPass.start(self)

	self:_updateRenderBuffer()

	self:getScene():getPipeline(LightPipeline):clusterLights(
		self:getQualityPreset(),
		self.renderBuffer:getWidth(),
		self.renderBuffer:getHeight(),
		self.lightClusterResult
	)
end

do
	local _screenSize = { 0, 0 }

	--- @private
	--- @param drawShader love.Shader
	--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
	function ReflectionRenderPass:_bindDrawShader(drawShader, pipelineRenderer)
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

		if drawShader:hasUniform("rat_ReflectionProbeCount") then
			drawShader:send("rat_ReflectionProbeCount", 0)
		end

		if drawShader:hasUniform("rat_PipelineGlobalIlluminationAtlasView") then
			drawShader:send(
				"rat_PipelineGlobalIlluminationAtlasView",
				ReflectionRenderPass.NIL_TEXTURE
			)
		end

		if drawShader:hasUniform("rat_PipelineReflectionAtlasView") then
			drawShader:send(
				"rat_PipelineReflectionAtlasView",
				ReflectionRenderPass.NIL_TEXTURE
			)
		end

		local screenSize = _screenSize
		screenSize[1], screenSize[2] =
			self.renderBuffer:getWidth(), self.renderBuffer:getHeight()
		drawShader:send("rat_ScreenSize", screenSize)

		if self:hasDependency(ShadowRenderPass) then
			self:getDependency(ShadowRenderPass):bind(drawShader)
		end
	end
end

--- @private
--- @param drawShader love.Shader
function ReflectionRenderPass:_drawForward(drawShader)
	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.setShader(drawShader)

	self:getRenderBuffer():bind()
	love.graphics.clear(0, 0, 0, 0)

	love.graphics.drawFromShaderIndirect(
		"triangles",
		self.cullResult:getIndirectBuffer()
	)
end

local BLUR_DIRECTION_X_AXIS = { 1, 0 }
local BLUR_DIRECTION_Y_AXIS = { 0, 1 }

--- @private
function ReflectionRenderPass:_blurGI()
	local activeCameraCount =
		self.cullResult:getCamerasBuffer():getActiveCameraCount()

	love.graphics.push("all")
	do
		love.graphics.setBlendState("add", "one", "zero")
		love.graphics.setDepthMode()

		local blurShader = self.blurShaderResource:get()
		love.graphics.setShader(blurShader)

		local activeCameraBuffer =
			self.cullResult:getCamerasBuffer():getActiveCameraBuffer()
		if blurShader:hasUniform("rat_LayersBuffer") then
			blurShader:send("rat_LayersBuffer", activeCameraBuffer:getBuffer())
		end

		self.blurDoubleBufferResult:start()
		do
			blurShader:send("rat_BlurDirection", BLUR_DIRECTION_X_AXIS)
			self.blurDoubleBufferResult:bindShaderInput(
				blurShader,
				"rat_ReflectionTexture"
			)
			self.blurDoubleBufferResult:bindShaderOutput()

			love.graphics.clear(0, 0, 0, 0)
			PostProcess.drawInstanced(activeCameraCount)
		end

		self.blurDoubleBufferResult:step()
		do
			blurShader:send("rat_BlurDirection", BLUR_DIRECTION_Y_AXIS)
			self.blurDoubleBufferResult:bindShaderInput(
				blurShader,
				"rat_ReflectionTexture"
			)
			self.blurDoubleBufferResult:bindShaderOutput()

			love.graphics.clear(0, 0, 0, 0)
			PostProcess.drawInstanced(activeCameraCount)
		end

		self.blurDoubleBufferResult:stop()
	end
	love.graphics.pop()
end

--- @private
--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
function ReflectionRenderPass:_generateHiZ(pipelineRenderer)
	pipelineRenderer:computeCubeMapHiZ(self:getQualityPreset(), self.hiZResult)
end

--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
function ReflectionRenderPass:draw(pipelineRenderer)
	local material = self:getWorld():getPipeline(MaterialPipeline)
	local drawShaderResource =
		material:getShader(self:getQualityPreset(), "forward", "draw")

	if not drawShaderResource:getIsReady() then
		return
	end

	local drawShader = drawShaderResource:get()
	self:_bindDrawShader(drawShader, pipelineRenderer)

	self:_drawForward(drawShader)
	self:_blurGI()
	self:_generateHiZ(pipelineRenderer)
end

return ReflectionRenderPass
