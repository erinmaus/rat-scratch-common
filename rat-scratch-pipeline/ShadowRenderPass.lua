local Object = require("rat-scratch-common").Object
local DoubleBufferResult = require("rat-scratch-pipeline.DoubleBufferResult")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")
local RenderPass = require("rat-scratch-pipeline.RenderPass")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Table = require("rat-scratch-common").Table
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local PostProcess = require("rat-scratch-pipeline.PostProcess")

--- @class RatScratch.Pipeline.ShadowRenderPass : RatScratch.Pipeline.RenderPass
--- @field private shadowAtlasRenderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private shadowAtlasOtherRenderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private shadowAtlasData number[]
--- @field private shadowAtlasBuffer love.GraphicsBuffer
--- @field private cullResult RatScratch.Pipeline.CullResult
--- @field private blurDoubleBufferResult RatScratch.Pipeline.DoubleBufferResult
--- @field private blurShaderResource RatScratch.Resource.Resource<love.Shader>
--- @overload fun(): RatScratch.Pipeline.ShadowRenderPass
local ShadowRenderPass = Object(RenderPass)

ShadowRenderPass.SHADOW_ATLAS_COLOR_CANVAS_FORMATS = {
	"rg32f",
}

ShadowRenderPass.SHADOW_ATLAS_COLOR_CANVAS_DEPTH_FORMAT = "depth16"

ShadowRenderPass.SHADOW_TEXTURE_ATLAS_FORMAT = {
	{ location = 0, name = "size", format = "floatvec2" },
	{ location = 1, name = "position", format = "floatvec2" },
	{ location = 2, name = "layer", format = "float" },
	{ location = 3, name = "cameraIndex", format = "uint32" },
}

ShadowRenderPass.SHADOW_TEXTURE_ATLAS_FORMAT_INSTANCE =
	BufferFormat.get(ShadowRenderPass.SHADOW_TEXTURE_ATLAS_FORMAT)

function ShadowRenderPass:attached()
	RenderPass.attached(self)

	local lightPipeline = self:getScene():getPipeline(LightPipeline)

	self.shadowAtlasRenderBuffer = RenderBuffer(
		ShadowRenderPass.SHADOW_ATLAS_COLOR_CANVAS_FORMATS,
		ShadowRenderPass.SHADOW_ATLAS_COLOR_CANVAS_DEPTH_FORMAT
	)
	self.shadowAtlasOtherRenderBuffer =
		RenderBuffer(ShadowRenderPass.SHADOW_ATLAS_COLOR_CANVAS_FORMATS)
	self.cullResult = lightPipeline:newCullResult()
	self.blurDoubleBufferResult = DoubleBufferResult(
		self.shadowAtlasRenderBuffer,
		self.shadowAtlasOtherRenderBuffer,
		1
	)
	self.shadowAtlasData = {}

	self.blurShaderResource = self:getPipelineRuntime():loadShader(
		"@Pipeline/Base/Shadow/Blur.frag.glsl",
		"@Pipeline/PostProcess/LayeredVertex.vert.glsl",
		self:getQualityPreset()
	)
end

function ShadowRenderPass:_updateShadowAtlasBuffer()
	local cameraCount = self.cullResult:getCamerasBuffer():getCameraCount()
	if
		not self.shadowAtlasBuffer
		or self.shadowAtlasBuffer:getElementCount() < cameraCount
	then
		self.shadowAtlasBuffer = love.graphics.newBuffer(
			ShadowRenderPass.SHADOW_TEXTURE_ATLAS_FORMAT,
			cameraCount,
			{ shaderstorage = true }
		)

		Table.clear(self.shadowAtlasData)
		local componentCount =
			ShadowRenderPass.SHADOW_TEXTURE_ATLAS_FORMAT_INSTANCE:getComponentCount()
		local offset = 1
		for i = 1, cameraCount do
			Table.copy(
				self.shadowAtlasData,
				offset,
				offset + componentCount - 1,
				1,
				1,
				0,
				0,
				i - 1,
				i - 1
			)

			offset = offset + componentCount
		end

		self.shadowAtlasBuffer:setArrayData(
			self.shadowAtlasData,
			1,
			1,
			cameraCount
		)
	end
end

function ShadowRenderPass:_updateRenderBuffer()
	local cameraCount = self.cullResult:getCamerasBuffer():getCameraCount()
	local width, height = self:getPipelineRuntime():getCurrentProperty(
		self:getQualityPreset(),
		"pipeline.properties.shadow.cascadeSizeInPixels"
	)

	self.shadowAtlasOtherRenderBuffer:resize(width, height, cameraCount)
	self.shadowAtlasRenderBuffer:resize(width, height, cameraCount)
end

function ShadowRenderPass:getCullResult()
	return self.cullResult
end

function ShadowRenderPass:getShadowResult()
	return self.blurDoubleBufferResult
end

function ShadowRenderPass:getSourceRenderBuffer()
	return self.shadowAtlasRenderBuffer
end

function ShadowRenderPass:getOtherRenderBuffer()
	return self.shadowAtlasOtherRenderBuffer
end

--- @param shader love.Shader
function ShadowRenderPass:bind(shader)
	if shader:hasUniform("rat_ShadowCamerasBuffer") then
		shader:send(
			"rat_ShadowCamerasBuffer",
			self.cullResult:getCamerasBuffer():getCameraBuffer():getBuffer()
		)
	end

	if shader:hasUniform("rat_ShadowTexturesBuffer") then
		shader:send("rat_ShadowTexturesBuffer", self.shadowAtlasBuffer)
	end

	if shader:hasUniform("rat_PipelineShadowTextureAtlasView") then
		shader:send(
			"rat_PipelineShadowTextureAtlasView",
			self.shadowAtlasRenderBuffer:getCanvas(1)
		)
	end
end

--- @private
--- @param drawShader love.Shader
--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
function ShadowRenderPass:_drawShadows(drawShader, pipelineRenderer)
	pipelineRenderer:bind(drawShader, self)

	if drawShader:hasUniform("rat_DrawsBuffer") then
		drawShader:send("rat_DrawsBuffer", self.cullResult:getDrawsBuffer())
	end

	if drawShader:hasUniform("rat_CamerasBuffer") then
		drawShader:send(
			"rat_CamerasBuffer",
			self.cullResult:getCamerasBuffer():getCameraBuffer():getBuffer()
		)
	end

	love.graphics.push("all")
	do
		love.graphics.setBlendState("add", "one", "zero")
		love.graphics.setShader(drawShader)

		self:getSourceRenderBuffer():bind()
		love.graphics.clear(0, 0, 0, 0)

		love.graphics.drawFromShaderIndirect(
			"triangles",
			self.cullResult:getIndirectBuffer()
		)
	end
	love.graphics.pop()
end

local BLUR_DIRECTION_X_AXIS = { 1, 0 }
local BLUR_DIRECTION_Y_AXIS = { 0, 1 }

--- @private
function ShadowRenderPass:_blurShadows()
	local cameraCount = self.cullResult:getCamerasBuffer():getCameraCount()
	love.graphics.push("all")
	do
		love.graphics.setBlendState("add", "one", "zero")

		local blurShader = self.blurShaderResource:get()
		love.graphics.setShader(blurShader)

		self.blurDoubleBufferResult:start()
		do
			blurShader:send("rat_BlurDirection", BLUR_DIRECTION_X_AXIS)
			self.blurDoubleBufferResult:bindShaderInput(
				blurShader,
				"rat_ShadowTexture"
			)
			self.blurDoubleBufferResult:bindShaderOutput()

			love.graphics.clear(0, 0, 0, 0)
			PostProcess.drawInstanced(cameraCount)
		end

		self.blurDoubleBufferResult:step()
		do
			blurShader:send("rat_BlurDirection", BLUR_DIRECTION_Y_AXIS)
			self.blurDoubleBufferResult:bindShaderInput(
				blurShader,
				"rat_ShadowTexture"
			)
			self.blurDoubleBufferResult:bindShaderOutput()

			love.graphics.clear(0, 0, 0, 0)
			PostProcess.drawInstanced(cameraCount)
		end

		self.blurDoubleBufferResult:stop()
	end
	love.graphics.pop()
end

function ShadowRenderPass:start()
	RenderPass.start(self)

	self:_updateRenderBuffer()
	self:_updateShadowAtlasBuffer()
end

--- @param pipelineRenderer RatScratch.Pipeline.PipelineRenderer
function ShadowRenderPass:draw(pipelineRenderer)
	local material = self:getWorld():getPipeline(MaterialPipeline)
	local drawShaderResource =
		material:getShader(self:getQualityPreset(), "shadow", "draw")

	if not drawShaderResource:getIsReady() then
		return
	end

	if not self.blurShaderResource:getIsReady() then
		return
	end

	local drawShader = drawShaderResource:get()
	self:_drawShadows(drawShader, pipelineRenderer)
	self:_blurShadows()
end

return ShadowRenderPass
