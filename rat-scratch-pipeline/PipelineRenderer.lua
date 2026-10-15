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
	if not self.cullShader:getIsReady() then
		return
	end

	local cullShader = self.cullShader:get()

	self:_bindWorldUniforms(cullShader)
	self:_bindSceneUniforms(cullShader, scene)

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

local BLUR_DIRECTION_X_AXIS = { 1, 0 }
local BLUR_DIRECTION_Y_AXIS = { 0, 1 }

--- @param shader love.Shader
--- @param rendererPass RatScratch.Pipeline.RenderPass
function PipelineRenderer:bind(shader, rendererPass)
	self:_bindWorldUniforms(shader)
	self:_bindSceneUniforms(shader, rendererPass:getScene())
end

--- @param forwardRenderPass RatScratch.Pipeline.ForwardRenderPass
function PipelineRenderer:drawForward(forwardRenderPass)
	if true then
		return
	end

	forwardRenderPass:start()

	local material = self.world:getPipeline(MaterialPipeline)

	local drawShader = material:getShader(
		forwardRenderPass:getQualityPreset(),
		"forward",
		"draw"
	)
	self:_bindWorldUniforms(drawShader)
	self:_bindSceneUniforms(drawShader, forwardRenderPass:getScene())

	forwardRenderPass:bind(drawShader)

	love.graphics.push("all")
	love.graphics.setShader(drawShader)
	forwardRenderPass:getRenderBuffer():bind()
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.drawFromShaderIndirect(
		"triangles",
		forwardRenderPass:getCullResult():getIndirectBuffer()
	)
	love.graphics.pop()

	forwardRenderPass:stop()

	-- TODO: oit
end

--- @param rendererPass RatScratch.Pipeline.RenderPass
function PipelineRenderer:draw(rendererPass)
	rendererPass:start()
	rendererPass:draw(self)
	rendererPass:stop()
end

return PipelineRenderer
