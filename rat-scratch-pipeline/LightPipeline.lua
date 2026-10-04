local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local CameraFrame = require("rat-scratch-pipeline.CameraFrame")
local Draw = require("rat-scratch-pipeline.Draw")
local Light = require("rat-scratch-pipeline.Light")
local LightEvent = require("rat-scratch-pipeline.LightEvent")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local PointLight = require("rat-scratch-pipeline.PointLight")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.LightPipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private lights table<RatScratch.Pipeline.Light, true>
--- @field private shadowCastingLights table<RatScratch.Pipeline.Light, true>
--- @field private dirtyLights table<RatScratch.Pipeline.Light, true>
--- @field private lightsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Light>
--- @field private lightData number[]
--- @field private camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
--- @field private cameras table<RatScratch.Pipeline.Camera, RatScratch.Pipeline.CameraFrame>
--- @field private _CELLS_BUFFER love.GraphicsBuffer
--- @field private clusterShaders table<string, love.Shader>
--- @field private cellShaders table<string, love.Shader>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.LightPipeline
local LightPipeline = Object(Pipeline)

LightPipeline.CELLS_FORMAT = {
	{ location = 0, name = "worldMin", format = "floatvec3" },
	{ location = 1, name = "worldMax", format = "floatvec3" },
}

LightPipeline.DEFAULT_LIGHTS_COUNT = 1024
LightPipeline.DEFAULT_CAMERA_COUNT = 64

--- @type love.GraphicsBuffer | false
LightPipeline._CELLS_BUFFER = false

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function LightPipeline:new(pipelineRuntime)
	Pipeline.new(self, pipelineRuntime)

	self.lights = {}
	self.shadowCastingLights = {}
	self.dirtyLights = {}

	self.lightsBuffer = PipelineBuffer(
		Light.LIGHT_FORMAT,
		{ shaderstorage = true },
		LightPipeline.DEFAULT_LIGHTS_COUNT
	)

	self.lightData =
		Table.new(Light.LIGHT_FORMAT_INSTANCE:getComponentCount(), 0)
	BufferFormat.resetValue(Light.LIGHT_FORMAT_INSTANCE, self.lightData)

	self.camerasBuffer = PipelineBuffer(
		CameraFrame.CAMERA_FORMAT,
		{ shaderstorage = true },
		LightPipeline.DEFAULT_CAMERA_COUNT
	)

	self.cameras = setmetatable({}, { __mode = "k" })

	self.clusterShaders = {}
	self.cellShaders = {}
end

--- @param shader love.Shader
--- @param qualityPreset string
function LightPipeline:bind(shader, qualityPreset)
	if shader:hasUniform("rat_LightsBuffer") then
		shader:send("rat_LightsBuffer", self.lightsBuffer:getBuffer())
	end
end

--- @param light RatScratch.Pipeline.Light
function LightPipeline:addLight(light)
	assert(not self.lights[light], "light already exists in light pipeline")

	self.lightsBuffer:register(light, 1)

	light:listen(LightEvent.UPDATE, self._onLightUpdate, self)

	self.lights[light] = true
	self.shadowCastingLights[light] = nil
	self.dirtyLights[light] = true
end

--- @param light RatScratch.Pipeline.Light
function LightPipeline:removeLight(light)
	assert(self.lights[light], "light not in light pipeline")

	self.lightsBuffer:unregister(light)

	if self.camerasBuffer:has(light) then
		self.camerasBuffer:unregister(light)
	end

	self.lights[light] = nil
	self.shadowCastingLights[light] = nil
	self.dirtyLights[light] = nil
end

--- @private
--- @param event RatScratch.Pipeline.LightEvent
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_onLightUpdate(event, light)
	local isShadowCastingLight = self.shadowCastingLights[light] ~= nil

	if isShadowCastingLight ~= light:getIsShadowCaster() then
		if light:getIsShadowCaster() then
			self:_addShadowCastingLight(light)
		else
			if self.camerasBuffer:has(light) then
				self.camerasBuffer:unregister(light)
			end

			self.shadowCastingLights[light] = nil
		end
	end

	self.dirtyLights[light] = true
end

--- @private
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_addShadowCastingLight(light)
	self.camerasBuffer:registerOrResize(light, light:getCameraCount())
	self.shadowCastingLights[light] = true
end

--- @private
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_flushShadowCastingLight(light)
	local count = light:getCameraCount()

	for i = 1, count do
		local camera = light:getCamera(i)
		local cameraFrame = self.cameras[camera]
		if not cameraFrame then
			cameraFrame = CameraFrame(camera)
			self.cameras[camera] = cameraFrame
		end

		cameraFrame:update()
		self.camerasBuffer:copyTable(light, cameraFrame:getData(), i, 1)
	end
end

--- @private
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_flushLight(light)
	light:toData(self.lightData)

	self.lightsBuffer:copyTable(light, self.lightData, 1, 1)

	if self.shadowCastingLights[light] then
		self:_flushShadowCastingLight(light)
	end

	light:update()
end

--- @private
function LightPipeline:_flushLights()
	for light in pairs(self.dirtyLights) do
		self:_flushLight(light)
		self.dirtyLights[light] = nil
	end
end

function LightPipeline:flush()
	if next(self.dirtyLights) then
		self.camerasBuffer:compact()
		self.lightsBuffer:compact()

		self:_flushLights()

		self.camerasBuffer:flush()
		self.lightsBuffer:flush()
	end
end

function LightPipeline:loadDefaultShaders()
	local runtime = self:getPipelineRuntime()

	Table.clear(self.clusterShaders)
	for i = 1, runtime:getQualityPresetCount() do
		local qualityPreset = runtime:getQualityPreset(i)
		self.clusterShaders[qualityPreset] =
			runtime:loadComputeShader("@Pipeline/Lights/Cluster.compute.glsl")
	end

	Table.clear(self.cellShaders)
	for i = 1, runtime:getQualityPresetCount() do
		local qualityPreset = runtime:getQualityPreset(i)
		self.cellShaders[qualityPreset] =
			runtime:loadComputeShader("@Pipeline/Lights/Cells.compute.glsl")
	end
end

--- @private
--- @param count integer
function LightPipeline._reserveCells(count)
	if
		not LightPipeline._CELLS_BUFFER
		or count > LightPipeline._CELLS_BUFFER:getElementCount()
	then
		LightPipeline._CELLS_BUFFER = love.graphics.newBuffer(
			LightPipeline.CELLS_FORMAT,
			math.max(count, 1),
			{ shaderstorage = true }
		)
	end

	return LightPipeline._CELLS_BUFFER
end

--- @private
--- @param qualityPreset string
--- @param shader love.Shader
--- @param result RatScratch.Pipeline.LightClusterResult
function LightPipeline:_dispatchCluster(qualityPreset, shader, result)
	shader:send("rat_LightsBuffer", self.lightsBuffer:getBuffer())

	local _, lightsCount = self.lightsBuffer:getIndexCount()
	shader:send("rat_LightCount", lightsCount)

	local cellsBuffer = LightPipeline._CELLS_BUFFER
	shader:send("rat_WorldCellsBuffer", cellsBuffer)

	local camerasBuffer = result:getCamerasBuffer()
	local _, cameraCount = camerasBuffer:getIndexCount()
	shader:send("rat_CameraCount", cameraCount)

	local cellsX, cellsY, cellsZ = self.pipelineRuntime:getCurrentProperty(
		qualityPreset,
		"pipeline.properties.lighting.cells"
	)
	local maxLightsPerCell = self.pipelineRuntime:getCurrentProperty(
		qualityPreset,
		"pipeline.properties.lighting.maxLightsPerCell"
	) or 0
	local maxLightsPerThread = self.pipelineRuntime:getCurrentProperty(
		qualityPreset,
		"pipeline.properties.lighting.maxLightsPerThread"
	) or 1
	local cellsCount = (cellsX or 0) * (cellsY or 0) * (cellsZ or 0)

	local minLightIndicesElementCount = cellsCount
		* (maxLightsPerCell + 1)
		* cameraCount
	local lightsIndicesBuffer =
		result:reserveLightIndices(minLightIndicesElementCount)
	lightsIndicesBuffer:clear()

	shader:send("rat_LightCountIndicesBuffer", lightsIndicesBuffer)

	local localSizeX, localSizeY, localSizeZ = shader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(cellsCount / localSizeX), 1),
		math.max(math.ceil(lightsCount / maxLightsPerThread / localSizeY), 1),
		math.max(math.ceil(cameraCount / localSizeZ), 1)
	)
end

--- @private
--- @param qualityPreset string
--- @param shader love.Shader
--- @param result RatScratch.Pipeline.LightClusterResult
function LightPipeline:_dispatchCells(qualityPreset, shader, result)
	local camerasBuffer = result:getCamerasBuffer()
	shader:send("rat_CamerasBuffer", camerasBuffer:getBuffer())

	local _, cameraCount = camerasBuffer:getIndexCount()
	shader:send("rat_CameraCount", cameraCount)

	local cellsX, cellsY, cellsZ = self.pipelineRuntime:getCurrentProperty(
		qualityPreset,
		"pipeline.properties.lighting.cells"
	)
	local cellsCount = (cellsX or 0) * (cellsY or 0) * (cellsZ or 0)

	local cellsBuffer = LightPipeline._reserveCells(cellsCount * cameraCount)
	shader:send("rat_WorldCellsBuffer", cellsBuffer)

	local localSizeX, localSizeY = shader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(cellsCount / localSizeX), 1),
		math.max(math.ceil(cameraCount / localSizeY), 1)
	)
end

--- @param qualityPreset string
--- @param result RatScratch.Pipeline.LightClusterResult
--- @return boolean, RatScratch.Pipeline.LightClusterResult
function LightPipeline:clusterLights(qualityPreset, result)
	local clusterShader = self.clusterShaders[qualityPreset]
	local cellShader = self.cellShaders[qualityPreset]
	if not (clusterShader and cellShader) then
		return false, result
	end

	self:_dispatchCells(qualityPreset, cellShader, result)
	self:_dispatchCluster(qualityPreset, clusterShader, result)

	return true, result
end

return LightPipeline
