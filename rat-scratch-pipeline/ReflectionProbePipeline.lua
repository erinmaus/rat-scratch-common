local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local CameraBuffer = require("rat-scratch-pipeline.CameraBuffer")
local Draw = require("rat-scratch-pipeline.Draw")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local ReflectionProbeEvent =
	require("rat-scratch-pipeline.ReflectionProbeEvent")
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.ReflectionProbePipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private probesByInstance table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private probesByIndex RatScratch.Pipeline.ReflectionProbe[]
--- @field private dirtyProbes table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private staticProbes table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private staticProbesByIndex RatScratch.Pipeline.ReflectionProbe[]
--- @field private realtimeProbes table<RatScratch.Pipeline.ReflectionProbe, true>
--- @field private realtimeProbesByIndex RatScratch.Pipeline.ReflectionProbe[]
--- @field private camerasBuffer RatScratch.Pipeline.CameraBuffer<RatScratch.Pipeline.ReflectionProbe>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.ReflectionProbePipeline
local ReflectionProbePipeline = Object(Pipeline)

ReflectionProbePipeline.ATLAS_FORMAT = {
	"srgba8",
}

ReflectionProbePipeline.ATLAS_DEPTH_FORMAT = "depth16"

function ReflectionProbePipeline:new(pipelineRuntime)
	Pipeline.new(self, pipelineRuntime)

	self.probesByInstance = {}
	self.probesByIndex = {}
	self.dirtyProbes = {}
	self.staticProbes = {}
	self.staticProbesByIndex = {}
	self.realtimeProbes = {}
	self.realtimeProbesByIndex = {}

	self.reflectionProbesAtlas = RenderBuffer(
		ReflectionProbePipeline.ATLAS_FORMAT,
		ReflectionProbePipeline.ATLAS_DEPTH_FORMAT
	)

	self.camerasBuffer = CameraBuffer()
end

--- @param probe RatScratch.Pipeline.ReflectionProbe
function ReflectionProbePipeline:add(probe)
	assert(not self.probesByInstance[probe], "probe exists in pipeline")

	self.probesByInstance[probe] = true
	self.camerasBuffer:register(probe, probe:getCameraCount())

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

	probe:silence(ReflectionProbeEvent.UPDATE, self._onProbeUpdate, self)
end

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

function ReflectionProbePipeline:_updateProbes()
	-- TODO: only X static probes per frame

	for probe in pairs(self.dirtyProbes) do
		self.camerasBuffer:activate(probe)
	end
end

function ReflectionProbeEvent:flush() end

return ReflectionProbePipeline
