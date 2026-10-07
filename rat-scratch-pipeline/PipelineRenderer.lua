local Object = require("rat-scratch-common").Object
local AnimationPipeline = require("rat-scratch-pipeline.AnimationPipeline")
local DrawPipeline = require("rat-scratch-pipeline.DrawPipeline")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local ModelPipeline = require("rat-scratch-pipeline.ModelPipeline")
local ObjectPipeline = require("rat-scratch-pipeline.ObjectPipeline")
local World = require("rat-scratch-pipeline.World")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local IndirectDraw = require("rat-scratch-pipeline.IndirectDraw")
local PostProcess = require("rat-scratch-pipeline.PostProcess")

--- @class RatScratch.Pipeline.PipelineRenderer : RatScratch.Common.BaseObject
--- @field private pipelineRuntime RatScratch.Pipeline.PipelineRuntime
--- @field private world RatScratch.Pipeline.World
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.PipelineRenderer
local PipelineRenderer = Object()

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function PipelineRenderer:new(pipelineRuntime)
	self.pipelineRuntime = pipelineRuntime
	self.world = World(pipelineRuntime)

	self.indirectDrawBufferData = {}
	BufferFormat.resetValue(
		DrawPipeline.INDIRECT_DRAW_FORMAT,
		self.indirectDrawBufferData
	)
	BufferFormat.setValue(
		IndirectDraw.INDIRECT_DRAW_FORMAT,
		self.indirectDrawBufferData,
		"vertexCount",
		0,
		pipelineRuntime:getConfig():getMeshletFormat():getTriangleCount() * 3
	)

	self.cullShader = pipelineRuntime:loadComputeShader(
		"@Pipeline/Cull/Cull.compute.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)

	self.shadowBlurShader = pipelineRuntime:loadShader(
		"@Pipeline/Base/Shadow/Blur.frag.glsl",
		"@Pipeline/PostProcess/LayeredVertex.vert.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)
end

function PipelineRenderer:getWorld()
	return self.world
end

function PipelineRenderer:update()
	self.world:flush()
end

--- @private
--- @param shader love.Shader
function PipelineRenderer:_bindWorldUniforms(shader)
	local material = self.world:getPipeline(MaterialPipeline)
	material:bind(shader, self.pipelineRuntime:getDefaultQualityPreset())

	local model = self.world:getPipeline(ModelPipeline)
	model:bind(shader, self.pipelineRuntime:getDefaultQualityPreset())

	local object = self.world:getPipeline(ObjectPipeline)
	object:bind(shader, self.pipelineRuntime:getDefaultQualityPreset())

	local animation = self.world:getPipeline(AnimationPipeline)
	animation:bind(shader, self.pipelineRuntime:getDefaultQualityPreset())
end

--- @private
--- @param shader love.Shader
--- @param scene RatScratch.Pipeline.Scene
function PipelineRenderer:_bindSceneUniforms(shader, scene)
	local draw = scene:getPipeline(DrawPipeline)
	draw:bind(shader, self.pipelineRuntime:getDefaultQualityPreset())

	local light = scene:getPipeline(LightPipeline)
	light:bind(shader, self.pipelineRuntime:getDefaultQualityPreset())

	scene:bind(shader, self.pipelineRuntime:getDefaultQualityPreset())
end

--- @private
--- @param scene RatScratch.Pipeline.Scene
function PipelineRenderer:_cullScene(scene)
	self:_bindWorldUniforms(self.cullShader)
	self:_bindSceneUniforms(self.cullShader, scene)

	local draw = scene:getPipeline(DrawPipeline)
	local drawsBuffer = draw:getDrawsBuffer()

	scene:getPipeline(DrawPipeline):cull(self.cullShader, 1)
end

--- @private
--- @param scene RatScratch.Pipeline.Scene
function PipelineRenderer:_drawForward(scene)
	self:_cullScene(scene)

	local material = self.world:getPipeline(MaterialPipeline)

	local drawShader = material:getShader(
		self.pipelineRuntime:getDefaultQualityPreset(),
		"forward",
		"draw"
	)
	self:_bindWorldUniforms(drawShader)
	self:_bindSceneUniforms(drawShader, scene)

	love.graphics.push("all")
	love.graphics.setShader(drawShader)
	scene:getPipeline(DrawPipeline):draw()
	love.graphics.pop()
end

--- @param qualityPreset string
--- @param scene RatScratch.Pipeline.Scene
--- @param result RatScratch.Pipeline.CullResult
function PipelineRenderer:cull(qualityPreset, scene, result)
	self:_bindWorldUniforms(self.cullShader)
	self:_bindSceneUniforms(self.cullShader, scene)

	result:getIndirectBuffer():setArrayData(self.indirectDrawBufferData)

	local draw = scene:getPipeline(DrawPipeline)
	local inputDrawsBuffer = draw:getDrawsBuffer()
	local _, inputDrawCount = inputDrawsBuffer:getIndexCount()
	result:reserveDraws(inputDrawCount)

	local _, cameraCount = result:getCamerasBuffer():getIndexCount()

	if self.cullShader:hasUniform("rat_DrawsBuffer") then
		self.cullShader:send("rat_DrawsBuffer", inputDrawsBuffer:getBuffer())
	end

	if self.cullShader:hasUniform("rat_OutputDrawsBuffer") then
		self.cullShader:send("rat_OutputDrawsBuffer", result:getDrawsBuffer())
	end

	if self.cullShader:hasUniform("rat_IndirectDrawsBuffer") then
		self.cullShader:send(
			"rat_IndirectDrawsBuffer",
			result:getIndirectBuffer()
		)
	end

	if self.cullShader:hasUniform("rat_DrawCount") then
		self.cullShader:send("rat_DrawCount", inputDrawCount)
	end

	if self.cullShader:hasUniform("rat_CameraCount") then
		self.cullShader:send("rat_CameraCount", cameraCount)
	end

	local localX, localY = self.cullShader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		self.cullShader,
		math.max(math.ceil(inputDrawCount / localX), 1),
		math.max(math.ceil(cameraCount / localY), 1)
	)
end

local BLUR_DIRECTION_X_AXIS = { 1, 0 }
local BLUR_DIRECTION_Y_AXIS = { 0, 1 }

--- @param qualityPreset string
--- @param scene RatScratch.Pipeline.Scene
--- @param result RatScratch.Pipeline.CullResult
function PipelineRenderer:drawShadows(qualityPreset, scene, result)
	local material = self.world:getPipeline(MaterialPipeline)

	local drawShader = material:getShader(qualityPreset, "shadow", "draw")
	self:_bindWorldUniforms(drawShader)
	self:_bindSceneUniforms(drawShader, scene)

	if drawShader:hasUniform("rat_DrawsBuffer") then
		drawShader:send("rat_DrawsBuffer", result:getDrawsBuffer())
	end

	love.graphics.push("all")
	do
		love.graphics.setShader(drawShader)
		scene:getPipeline(LightPipeline):setCanvas()
		love.graphics.drawFromShaderIndirect(
			"triangles",
			result:getIndirectBuffer()
		)
		love.graphics.pop()
	end

	local _, cameraCount = result:getCamerasBuffer():getIndexCount()
	local blurResult = scene:getPipeline(LightPipeline):getShadowBlurResult()

	love.graphics.push("all")
	do
		love.graphics.setShader(self.shadowBlurShader)

		blurResult:start()
		do
			self.shadowBlurShader:send(
				"rat_BlurDirection",
				BLUR_DIRECTION_X_AXIS
			)
			blurResult:bindShaderInput(
				self.shadowBlurShader,
				"rat_ShadowTexture"
			)
			blurResult:bindShaderOutput()
			PostProcess.drawInstanced(cameraCount)
		end

		blurResult:step()
		do
			self.shadowBlurShader:send(
				"rat_BlurDirection",
				BLUR_DIRECTION_Y_AXIS
			)
			blurResult:bindShaderInput(
				self.shadowBlurShader,
				"rat_ShadowTexture"
			)
			blurResult:bindShaderOutput()
			PostProcess.drawInstanced(cameraCount)
		end

		blurResult:stop()
	end
	love.graphics.pop()
end

--- @param qualityPreset string
--- @param scene RatScratch.Pipeline.Scene
--- @param result RatScratch.Pipeline.CullResult
function PipelineRenderer:drawForward(qualityPreset, scene, result)
	local material = self.world:getPipeline(MaterialPipeline)

	local drawShader = material:getShader(qualityPreset, "forward", "draw")
	self:_bindWorldUniforms(drawShader)
	self:_bindSceneUniforms(drawShader, scene)

	if drawShader:hasUniform("rat_DrawsBuffer") then
		drawShader:send("rat_DrawsBuffer", result:getDrawsBuffer())
	end

	love.graphics.push("all")
	love.graphics.setShader(drawShader)
	love.graphics.drawFromShaderIndirect(
		"triangles",
		result:getIndirectBuffer()
	)
	love.graphics.pop()

	-- TODO: OIT
end

--- @param scene RatScratch.Pipeline.Scene
function PipelineRenderer:draw(scene)
	self:_drawForward(scene)
end

return PipelineRenderer
