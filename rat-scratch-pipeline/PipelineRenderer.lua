local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local AnimationPipeline = require("rat-scratch-pipeline.AnimationPipeline")
local DrawPipeline = require("rat-scratch-pipeline.DrawPipeline")
local LightClusterResult = require("rat-scratch-pipeline.LightClusterResult")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local ModelPipeline = require("rat-scratch-pipeline.ModelPipeline")
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local ObjectPipeline = require("rat-scratch-pipeline.ObjectPipeline")
local Pipelines = require("rat-scratch-pipeline.Pipelines")
local World = require("rat-scratch-pipeline.World")

--- @class RatScratch.Pipeline.PipelineRenderer : RatScratch.Common.BaseObject
--- @field private pipelineRuntime RatScratch.Pipeline.PipelineRuntime
--- @field private world RatScratch.Pipeline.World
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.PipelineRenderer
local PipelineRenderer = Object()

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function PipelineRenderer:new(pipelineRuntime)
	self.pipelineRuntime = pipelineRuntime
	self.world = World(pipelineRuntime)
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
function PipelineRenderer:_drawForward(scene)
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

--- @param scene RatScratch.Pipeline.Scene
function PipelineRenderer:draw(scene)
	self:_drawForward(scene)
end

return PipelineRenderer
