local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local CameraBuffer = require("rat-scratch-pipeline.CameraBuffer")
local CubeMap = require("rat-scratch-graphics.CubeMap")
local CullResult = require("rat-scratch-pipeline.CullResult")
local LightClusterResult = require("rat-scratch-pipeline.LightClusterResult")
local ReflectionProbe = require("rat-scratch-pipeline.ReflectionProbe")
local ReflectionProbeEvent =
	require("rat-scratch-pipeline.ReflectionProbeEvent")
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")

--- @class RatScratch.Pipeline.ReflectionProbePipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private probesByInstance table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private probesByIndex RatScratch.Pipeline.ReflectionProbe[]
--- @field private dirtyProbes table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private staticProbes table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private staleStaticProbes table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private staticProbesByIndex RatScratch.Pipeline.ReflectionProbe[]
--- @field private realtimeProbes table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private realtimeProbesByIndex RatScratch.Pipeline.ReflectionProbe[]
--- @field private camerasBuffer RatScratch.Pipeline.CameraBuffer<RatScratch.Pipeline.ReflectionProbe>
--- @field private workingReflectionProbeData number[]
--- @field private clusterShaders table<string, RatScratch.Resource.Resource<love.Shader>>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.ReflectionProbePipeline
local ReflectionProbePipeline = Object(Pipeline)

ReflectionProbePipeline.ATLAS_FORMAT = {
	"srgba8",
}

ReflectionProbePipeline.ATLAS_DEPTH_FORMAT = "depth16"

ReflectionProbePipeline.DEFAULT_REFLECTION_PROBE_COUNT = 32

function ReflectionProbePipeline:new(pipelineRuntime)
	Pipeline.new(self, pipelineRuntime)

	self.probesByInstance = {}
	self.probesByIndex = {}
	self.dirtyProbes = {}
	self.staticProbes = {}
	self.staleStaticProbes = {}
	self.staticProbesByIndex = {}
	self.realtimeProbes = {}
	self.realtimeProbesByIndex = {}

	self.reflectionProbesAtlas = RenderBuffer(
		ReflectionProbePipeline.ATLAS_FORMAT,
		ReflectionProbePipeline.ATLAS_DEPTH_FORMAT
	)

	self.reflectionProbesBuffer = PipelineBuffer(
		ReflectionProbe.REFLECTION_PROBE_FORMAT,
		{ shaderstorage = true },
		ReflectionProbePipeline.DEFAULT_REFLECTION_PROBE_COUNT
	)

	self.camerasBuffer = CameraBuffer()

	self.workingReflectionProbeData = {}
	BufferFormat.resetValue(
		ReflectionProbe.REFLECTION_PROBE_FORMAT,
		self.workingReflectionProbeData
	)

	self.clusterShaders = {}
end

function ReflectionProbePipeline:newCullResult()
	return CullResult(self.camerasBuffer)
end

function ReflectionProbePipeline:newLightClusterResult()
	return LightClusterResult(self.camerasBuffer)
end

function ReflectionProbePipeline:getProbeCount()
	local _, count = self.reflectionProbesBuffer:getIndexCount()
	return count
end

--- @param probe RatScratch.Pipeline.ReflectionProbe
function ReflectionProbePipeline:add(probe)
	assert(not self.probesByInstance[probe], "probe exists in pipeline")

	self.probesByInstance[probe] = true
	self.dirtyProbes[probe] = true

	self.camerasBuffer:register(probe, probe:getCameraCount())
	self.reflectionProbesBuffer:register(probe, 1)

	probe:listen(ReflectionProbeEvent.UPDATE, self._onProbeUpdate, self)

	if probe:getIsStatic() then
		self.staticProbes[probe] = true
	else
		self.realtimeProbes[probe] = true
	end

	for i = 1, probe:getCameraCount() do
		self.camerasBuffer:set(probe, i, probe:getCamera(i))
	end
end

--- @param probe RatScratch.Pipeline.ReflectionProbe
function ReflectionProbePipeline:remove(probe)
	assert(self.probesByInstance[probe], "probe does not exist in pipeline")

	self.probesByInstance[probe] = nil
	self.dirtyProbes[probe] = nil
	self.staticProbes[probe] = nil
	self.realtimeProbes[probe] = nil

	self.camerasBuffer:unregister(probe)
	self.reflectionProbesBuffer:unregister(probe)

	probe:silence(ReflectionProbeEvent.UPDATE, self._onProbeUpdate, self)
end

--- @private
--- @param probe RatScratch.Pipeline.ReflectionProbe
function ReflectionProbePipeline:_onProbeUpdate(event, probe)
	if self.staticProbes[probe] and probe:getIsRealtime() then
		self.staticProbes[probe] = nil
		self.realtimeProbes[probe] = true

		Table.remove(self.staticProbesByIndex, probe)
		table.insert(self.realtimeProbesByIndex, probe)
	elseif self.realtimeProbes[probe] and probe:getIsStatic() then
		self.staticProbes[probe] = true
		self.realtimeProbes[probe] = nil

		table.insert(self.staticProbesByIndex, probe)
		Table.remove(self.realtimeProbesByIndex, probe)
	end

	self.dirtyProbes[probe] = true
end

--- @private
function ReflectionProbePipeline:_deactivatePreviousStaticProbes()
	for probe in pairs(self.staleStaticProbes) do
		self.camerasBuffer:deactivate(probe)
		self.staleStaticProbes[probe] = nil
	end
end

--- @private
--- @param probe RatScratch.Pipeline.ReflectionProbe
function ReflectionProbePipeline:_updateProbe(probe)
	probe:update()

	self.camerasBuffer:activate(probe)

	Table.transfer(
		self.workingReflectionProbeData,
		probe:getData(),
		#self.workingReflectionProbeData
	)

	local index = self.camerasBuffer:getCameraBuffer():getIndexCount(probe)
	BufferFormat.setValue(
		ReflectionProbe.REFLECTION_PROBE_FORMAT,
		self.workingReflectionProbeData,
		"atlasImageIndexCount",
		0,
		index - 1,
		CubeMap.FACES
	)

	self.reflectionProbesBuffer:copyTable(
		probe,
		self.workingReflectionProbeData,
		1,
		1
	)
end

--- @private
function ReflectionProbePipeline:_updateProbes()
	-- TODO: only X static probes per frame

	for probe in pairs(self.dirtyProbes) do
		self:_updateProbe(probe)

		if self.staticProbes[probe] then
			self.staleStaticProbes[probe] = true
		end

		self.dirtyProbes[probe] = nil
	end
end

function ReflectionProbePipeline:update()
	if next(self.staleStaticProbes) then
		self:_deactivatePreviousStaticProbes()
	end

	if next(self.dirtyProbes) then
		self:_updateProbes()
	end

	self.camerasBuffer:update()
end

function ReflectionProbePipeline:flush()
	self.reflectionProbesBuffer:compact()
	self.reflectionProbesBuffer:flush()

	self.camerasBuffer:flush()
end

function ReflectionProbePipeline:loadDefaultShaders()
	local runtime = self:getPipelineRuntime()

	Table.clear(self.clusterShaders)
	for i = 1, runtime:getQualityPresetCount() do
		local qualityPreset = runtime:getQualityPreset(i)
		self.clusterShaders[qualityPreset] = runtime:loadComputeShader(
			"@Pipeline/Reflections/Cluster.compute.glsl"
		)
	end
end

--- @param shader love.Shader
--- @param qualityPreset string
function ReflectionProbePipeline:bind(shader, qualityPreset)
	if shader:hasUniform("rat_ReflectionProbesBuffer") then
		shader:send(
			"rat_ReflectionProbesBuffer",
			self.reflectionProbesBuffer:getBuffer()
		)
	end
end

do
	local _screenSize = { 0, 0 }

	--- @private
	--- @param qualityPreset string
	--- @param shader love.Shader
	--- @param screenWidth integer
	--- @param screenHeight integer
	--- @param result RatScratch.Pipeline.ReflectionProbeClusterResult
	function ReflectionProbePipeline:_dispatchCluster(
		qualityPreset,
		screenWidth,
		screenHeight,
		shader,
		result
	)
		shader:send(
			"rat_ReflectionProbesBuffer",
			self.reflectionProbesBuffer:getBuffer()
		)

		local screenSize = _screenSize
		screenSize[1], screenSize[2] = screenWidth, screenHeight
		shader:send("rat_ScreenSize", screenSize)

		local _, probesCount = self.reflectionProbesBuffer:getIndexCount()
		shader:send("rat_ReflectionProbeCount", probesCount)

		local camerasBuffer = result:getCamerasBuffer()
		camerasBuffer:bind(shader)

		local cellSizeX, cellSizeY = self.pipelineRuntime:getCurrentProperty(
			qualityPreset,
			"pipeline.properties.reflection.cellsSizeInPixels"
		)
		local maxProbesPerCell = self.pipelineRuntime:getCurrentProperty(
			qualityPreset,
			"pipeline.properties.reflection.maxProbesPerCell"
		) or 0
		local maxProbesPerThread = self.pipelineRuntime:getCurrentProperty(
			qualityPreset,
			"pipeline.properties.reflection.maxProbesPerThread"
		) or 1

		local cellsCount = math.ceil(screenWidth / (cellSizeX or 1))
			* math.ceil(screenHeight / (cellSizeY or 1))

		local minReflectionProbeIndicesElementCount = cellsCount
			* (maxProbesPerCell + 1)
			* camerasBuffer:getCameraCount()
		local reflectionProbeIndicesBuffer =
			result:reserveReflectionProbeIndices(
				minReflectionProbeIndicesElementCount
			)
		reflectionProbeIndicesBuffer:clear()

		shader:send(
			"rat_ReflectionProbeCountIndicesBuffer",
			reflectionProbeIndicesBuffer
		)

		local localSizeX, localSizeY, localSizeZ =
			shader:getLocalThreadgroupSize()
		love.graphics.dispatchThreadgroups(
			shader,
			math.max(math.ceil(cellsCount / localSizeX), 1),
			math.max(
				math.ceil(probesCount / maxProbesPerThread / localSizeY),
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
--- @param result RatScratch.Pipeline.ReflectionProbeClusterResult
--- @param screenWidth integer
--- @param screenHeight integer
--- @return boolean, RatScratch.Pipeline.ReflectionProbeClusterResult
function ReflectionProbePipeline:clusterReflectionProbes(
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

return ReflectionProbePipeline
