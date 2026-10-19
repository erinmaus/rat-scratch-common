local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.ReflectionProbeClusterResult : RatScratch.Common.BaseObject
--- @field private camerasBuffer RatScratch.Pipeline.CameraBuffer
--- @field private lightIndicesBuffer love.GraphicsBuffer
--- @overload fun(camerasBuffer: RatScratch.Pipeline.CameraBuffer): RatScratch.Pipeline.ReflectionProbeClusterResult
local ReflectionProbeClusterResult = Object()

ReflectionProbeClusterResult.REFLECTION_PROBE_INDICES_FORMAT = {
	{ location = 0, name = "index", format = "uint32" },
}

--- @param camerasBuffer RatScratch.Pipeline.CameraBuffer
function ReflectionProbeClusterResult:new(camerasBuffer)
	self.camerasBuffer = camerasBuffer
end

--- @return RatScratch.Pipeline.CameraBuffer
function ReflectionProbeClusterResult:getCamerasBuffer()
	return self.camerasBuffer
end

--- @return love.GraphicsBuffer
function ReflectionProbeClusterResult:getReflectionProbeIndicesBuffer()
	return self.lightIndicesBuffer
end

function ReflectionProbeClusterResult:hasResult()
	return self.lightIndicesBuffer ~= nil
end

--- @param count integer
function ReflectionProbeClusterResult:reserveReflectionProbeIndices(count)
	if
		not self.lightIndicesBuffer
		or count > self.lightIndicesBuffer:getElementCount()
	then
		self.lightIndicesBuffer = love.graphics.newBuffer(
			ReflectionProbeClusterResult.REFLECTION_PROBE_INDICES_FORMAT,
			math.max(count, 1),
			{ shaderstorage = true }
		)
	end

	return self.lightIndicesBuffer
end

return ReflectionProbeClusterResult
