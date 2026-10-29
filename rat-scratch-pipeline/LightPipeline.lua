local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local CameraBuffer = require("rat-scratch-pipeline.CameraBuffer")
local CameraFrame = require("rat-scratch-pipeline.CameraFrame")
local CullResult = require("rat-scratch-pipeline.CullResult")
local DoubleBufferResult = require("rat-scratch-pipeline.DoubleBufferResult")
local Draw = require("rat-scratch-pipeline.Draw")
local Light = require("rat-scratch-pipeline.Light")
local LightEvent = require("rat-scratch-pipeline.LightEvent")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local PointLight = require("rat-scratch-pipeline.PointLight")
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.LightPipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private lights table<RatScratch.Pipeline.Light, true>
--- @field private shadowCastingLights table<RatScratch.Pipeline.Light, true>
--- @field private shadowAtlasColor RatScratch.Pipeline.RenderBuffer
--- @field private shadowAtlasOtherColor RatScratch.Pipeline.RenderBuffer
--- @field private shadowBlurResult RatScratch.Pipeline.DoubleBufferResult
--- @field private dirtyLights table<RatScratch.Pipeline.Light, true>
--- @field private lightsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Light>
--- @field private lightData number[]
--- @field private camerasBuffer RatScratch.Pipeline.CameraBuffer
--- @field private cameras table<RatScratch.Pipeline.Camera, RatScratch.Pipeline.CameraFrame>
--- @field private _CELLS_BUFFER love.GraphicsBuffer
--- @field private clusterShaders table<string, RatScratch.Resource.Resource<love.Shader>>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.LightPipeline
local LightPipeline = Object(Pipeline)

LightPipeline.SHADOW_TEXTURE_ATLAS_FORMAT = {
	{ location = 0, name = "size", format = "floatvec2" },
	{ location = 1, name = "position", format = "floatvec2" },
	{ location = 2, name = "layer", format = "float" },
	{ location = 3, name = "cameraIndex", format = "uint32" },
}

LightPipeline.DEFAULT_LIGHTS_COUNT = 1024
LightPipeline.DEFAULT_CAMERA_COUNT = 64

LightPipeline.SHADOW_ATLAS_COLOR_CANVAS_FORMATS = {
	"rg32f",
}

LightPipeline.SHADOW_ATLAS_COLOR_CANVAS_DEPTH_FORMAT = "depth32f"

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

	--- @type integer?, integer?
	local width, height = pipelineRuntime:getCurrentProperty(
		pipelineRuntime:getDefaultQualityPreset(),
		"pipeline.properties.shadow.cascadeSizeInPixels"
	)
	assert(
		width and height,
		"missing property: 'pipeline.properties.shadow.cascadeSizeInPixels'"
	)

	self.currentCameraCount = 1

	self.shadowAtlasColor = RenderBuffer(
		LightPipeline.SHADOW_ATLAS_COLOR_CANVAS_FORMATS,
		LightPipeline.SHADOW_ATLAS_COLOR_CANVAS_DEPTH_FORMAT
	)
	self.shadowAtlasOtherColor =
		RenderBuffer(LightPipeline.SHADOW_ATLAS_COLOR_CANVAS_FORMATS)

	self.shadowAtlasColor:resize(width, height, 1)
	self.shadowAtlasOtherColor:resize(width, height, 1)

	self.shadowAtlasData = {}
	self.shadowAtlasBuffer = love.graphics.newBuffer(
		LightPipeline.SHADOW_TEXTURE_ATLAS_FORMAT,
		1,
		{ shaderstorage = true }
	)

	self.camerasBuffer = CameraBuffer()

	self.clusterShaders = {}
end

--- @param shader love.Shader
--- @param qualityPreset string
function LightPipeline:bind(shader, qualityPreset)
	if shader:hasUniform("rat_LightsBuffer") then
		shader:send("rat_LightsBuffer", self.lightsBuffer:getBuffer())
	end

	if shader:hasUniform("rat_ShadowCamerasBuffer") then
		shader:send(
			"rat_ShadowCamerasBuffer",
			self.camerasBuffer:getCameraBuffer():getBuffer()
		)
	end

	if shader:hasUniform("rat_PipelineShadowTextureAtlasView") then
		shader:send(
			"rat_PipelineShadowTextureAtlasView",
			self.shadowAtlasColor:getCanvas(1)
		)
	end

	if shader:hasUniform("rat_ShadowTexturesBuffer") then
		shader:send("rat_ShadowTexturesBuffer", self.shadowAtlasBuffer)
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

	light:silence(LightEvent.UPDATE, self._onLightUpdate, self)
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

	local count = light:getCameraCount()
	for i = 1, count do
		local camera = light:getCamera(i)
		self.camerasBuffer:set(light, i, camera)
	end

	self.camerasBuffer:activate(light)
end

--- @private
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_flushLight(light)
	light:toData(self.lightData)

	local cameraIndex, cameraCount = 0, 0
	if self.camerasBuffer:has(light) then
		cameraIndex, cameraCount =
			self.camerasBuffer:getCameraBuffer():getIndexCount(light)
	end

	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		self.lightData,
		"shadowTextureIndexCount",
		0,
		cameraIndex - 1,
		cameraCount
	)

	self.lightsBuffer:copyTable(light, self.lightData, 1, 1)

	light:update()
end

--- @private
function LightPipeline:_flushLights()
	for light in pairs(self.dirtyLights) do
		self:_flushLight(light)
		self.dirtyLights[light] = nil
	end
end

--- @private
function LightPipeline:_flushShadowAtlas()
	local cameraCount = self.camerasBuffer:getCameraCount()
	if self.currentCameraCount < cameraCount then
		self.currentCameraCount = cameraCount

		--- @type integer?, integer?
		local width, height = self:getPipelineRuntime():getCurrentProperty(
			self:getPipelineRuntime():getDefaultQualityPreset(),
			"pipeline.properties.shadow.cascadeSizeInPixels"
		)

		--- @cast width integer
		--- @cast height integer

		self.shadowAtlasColor:resize(width, height, cameraCount)
		self.shadowAtlasOtherColor:resize(width, height, cameraCount)

		self.shadowAtlasBuffer = love.graphics.newBuffer(
			LightPipeline.SHADOW_TEXTURE_ATLAS_FORMAT,
			cameraCount,
			{ shaderstorage = true }
		)

		Table.clear(self.shadowAtlasData)
		local formatInstance =
			BufferFormat.get(LightPipeline.SHADOW_TEXTURE_ATLAS_FORMAT)
		local componentCount = formatInstance:getComponentCount()
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

function LightPipeline:flush()
	if next(self.dirtyLights) then
		self.lightsBuffer:compact()

		self:_flushLights()

		self.camerasBuffer:flush()
		self.lightsBuffer:flush()

		self:_flushShadowAtlas()
	end

	self.camerasBuffer:flush()
end

function LightPipeline:update()
	self.camerasBuffer:update()
end

function LightPipeline:newCullResult()
	return CullResult(self.camerasBuffer)
end

function LightPipeline:newShadowBlurDoubleBufferResult()
	return DoubleBufferResult(
		self.shadowAtlasColor,
		self.shadowAtlasOtherColor,
		1
	)
end

function LightPipeline:loadDefaultShaders()
	local runtime = self:getPipelineRuntime()

	Table.clear(self.clusterShaders)
	for i = 1, runtime:getQualityPresetCount() do
		local qualityPreset = runtime:getQualityPreset(i)
		self.clusterShaders[qualityPreset] =
			runtime:loadComputeShader("@Pipeline/Lights/Cluster.compute.glsl")
	end
end

do
	local _screenSize = { 0, 0 }

	--- @private
	--- @param qualityPreset string
	--- @param shader love.Shader
	--- @param screenWidth integer
	--- @param screenHeight integer
	--- @param result RatScratch.Pipeline.LightClusterResult
	function LightPipeline:_dispatchCluster(
		qualityPreset,
		screenWidth,
		screenHeight,
		shader,
		result
	)
		shader:send("rat_LightsBuffer", self.lightsBuffer:getBuffer())

		local screenSize = _screenSize
		screenSize[1], screenSize[2] = screenWidth, screenHeight
		shader:send("rat_ScreenSize", screenSize)

		local _, lightsCount = self.lightsBuffer:getIndexCount()
		shader:send("rat_LightCount", lightsCount)

		local camerasBuffer = result:getCamerasBuffer()
		camerasBuffer:bind(shader)

		local cellSizeX, cellSizeY = self.pipelineRuntime:getCurrentProperty(
			qualityPreset,
			"pipeline.properties.lighting.cellsSizeInPixels"
		)
		local maxLightsPerCell = self.pipelineRuntime:getCurrentProperty(
			qualityPreset,
			"pipeline.properties.lighting.maxLightsPerCell"
		) or 0
		local maxLightsPerThread = self.pipelineRuntime:getCurrentProperty(
			qualityPreset,
			"pipeline.properties.lighting.maxLightsPerThread"
		) or 1

		local cellsCount = math.ceil(screenWidth / (cellSizeX or 1))
			* math.ceil(screenHeight / (cellSizeY or 1))

		local minLightIndicesElementCount = cellsCount
			* (maxLightsPerCell + 1)
			* camerasBuffer:getCameraCount()
		local lightsIndicesBuffer =
			result:reserveLightIndices(minLightIndicesElementCount)
		lightsIndicesBuffer:clear()

		shader:send("rat_LightCountIndicesBuffer", lightsIndicesBuffer)

		local localSizeX, localSizeY, localSizeZ =
			shader:getLocalThreadgroupSize()
		love.graphics.dispatchThreadgroups(
			shader,
			math.max(math.ceil(cellsCount / localSizeX), 1),
			math.max(
				math.ceil(lightsCount / maxLightsPerThread / localSizeY),
				1
			),
			math.max(
				math.ceil(camerasBuffer:getActiveCameraCount() / localSizeZ),
				1
			)
		)
	end
end

--- @param qualityPreset string
--- @param result RatScratch.Pipeline.LightClusterResult
--- @param screenWidth integer
--- @param screenHeight integer
--- @return boolean, RatScratch.Pipeline.LightClusterResult
function LightPipeline:clusterLights(
	qualityPreset,
	screenWidth,
	screenHeight,
	result
)
	local clusterShader = self.clusterShaders[qualityPreset]
	if not (clusterShader and clusterShader:getIsReady()) then
		return false, result
	end

	self:_dispatchCluster(
		qualityPreset,
		screenWidth,
		screenHeight,
		clusterShader:get(),
		result
	)

	return true, result
end

return LightPipeline
