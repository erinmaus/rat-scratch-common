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
local ReflectionProbePipeline =
	require("rat-scratch-pipeline.ReflectionProbePipeline")

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
--- @param qualityPreset string
function PipelineRenderer:_bindWorldUniforms(shader, qualityPreset)
	local material = self.world:getPipeline(MaterialPipeline)
	material:bind(shader, qualityPreset)

	local model = self.world:getPipeline(ModelPipeline)
	model:bind(shader, qualityPreset)

	local object = self.world:getPipeline(ObjectPipeline)
	object:bind(shader, qualityPreset)

	local animation = self.world:getPipeline(AnimationPipeline)
	animation:bind(shader, qualityPreset)
end

--- @private
--- @param shader love.Shader
--- @param scene RatScratch.Pipeline.Scene
--- @param qualityPreset string
function PipelineRenderer:_bindSceneUniforms(shader, scene, qualityPreset)
	local draw = scene:getPipeline(DrawPipeline)
	draw:bind(shader, qualityPreset)

	local light = scene:getPipeline(LightPipeline)
	light:bind(shader, qualityPreset)

	local reflection = scene:getPipeline(ReflectionProbePipeline)
	reflection:bind(shader, qualityPreset)

	scene:bind(shader, qualityPreset)
end

--- @param qualityPreset string
--- @param scene RatScratch.Pipeline.Scene
--- @param result RatScratch.Pipeline.CullResult
function PipelineRenderer:cull(qualityPreset, scene, result)
	if not self.cullShader:getIsReady() then
		return
	end

	local cullShader = self.cullShader:get()

	self:_bindWorldUniforms(cullShader, qualityPreset)
	self:_bindSceneUniforms(cullShader, scene, qualityPreset)

	result:getIndirectBuffer():setArrayData(self.indirectDrawBufferData)

	local draw = scene:getPipeline(DrawPipeline)
	local inputDrawsBuffer = draw:getDrawsBuffer()
	local _, inputDrawCount = inputDrawsBuffer:getIndexCount()
	result:reserveDraws(inputDrawCount)

	local cameraCount = result:getCamerasBuffer():getActiveCameraCount()

	if cullShader:hasUniform("rat_DrawsBuffer") then
		cullShader:send("rat_DrawsBuffer", inputDrawsBuffer:getBuffer())
	end

	if cullShader:hasUniform("rat_OutputDrawsBuffer") then
		cullShader:send("rat_OutputDrawsBuffer", result:getDrawsBuffer())
	end

	if cullShader:hasUniform("rat_IndirectDrawsBuffer") then
		cullShader:send("rat_IndirectDrawsBuffer", result:getIndirectBuffer())
	end

	if cullShader:hasUniform("rat_DrawCount") then
		cullShader:send("rat_DrawCount", inputDrawCount)
	end

	result:getCamerasBuffer():bind(cullShader)

	local localX, localY = cullShader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		cullShader,
		math.max(math.ceil(inputDrawCount / localX), 1),
		math.max(math.ceil(cameraCount / localY), 1)
	)
end

--- @param shader love.Shader
--- @param rendererPass RatScratch.Pipeline.RenderPass
function PipelineRenderer:bind(shader, rendererPass)
	self:_bindWorldUniforms(shader, rendererPass:getQualityPreset())
	self:_bindSceneUniforms(
		shader,
		rendererPass:getScene(),
		rendererPass:getQualityPreset()
	)
end

--- @param rendererPass RatScratch.Pipeline.RenderPass
function PipelineRenderer:draw(rendererPass)
	rendererPass:start()
	rendererPass:draw(self)
	rendererPass:stop()
end

return PipelineRenderer
