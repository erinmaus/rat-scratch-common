local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3

--- @class RatScratch.Pipeline.Graphics3D.PipelineMeshletBounds
--- @field public center RatScratch.Math.Vector3
--- @field public radius number
local PipelineMeshletBounds = {}

--- @class RatScratch.Pipeline.Graphics3D.PipelineMeshletSkinnedBounds : RatScratch.Pipeline.Graphics3D.PipelineMeshletBounds
--- @field public animation integer
--- @field public bone integer
local PipelineMeshletBounds = {}

--- @class RatScratch.Pipeline.Graphics3D.PipelineMeshlet : RatScratch.Common.BaseObject
--- @field private indices love.Data
--- @field private staticBounds RatScratch.Pipeline.Graphics3D.PipelineMeshletBounds
--- @field private skinnedBounds table<integer, RatScratch.Pipeline.Graphics3D.PipelineMeshletSkinnedBounds>
--- @field private skinnedBoundsByIndex RatScratch.Pipeline.Graphics3D.PipelineMeshletSkinnedBounds[]
--- @field private isSkinned boolean
--- @overload fun(indices: love.Data, staticBounds: RatScratch.Pipeline.Graphics3D.PipelineMeshletBounds, skinnedBounds?: table<integer, RatScratch.Pipeline.Graphics3D.PipelineMeshletSkinnedBounds>): RatScratch.Pipeline.Graphics3D.PipelineMeshlet
local PipelineMeshlet = Object()

--- @param a RatScratch.Pipeline.Graphics3D.PipelineMeshletSkinnedBounds
--- @param b RatScratch.Pipeline.Graphics3D.PipelineMeshletSkinnedBounds
local function _skinnedBoundsLess(a, b)
	return a.animation < b.animation
end

--- @param indices love.Data
--- @param staticBounds RatScratch.Pipeline.Graphics3D.PipelineMeshletBounds
--- @param skinnedBounds? table<integer, RatScratch.Pipeline.Graphics3D.PipelineMeshletSkinnedBounds>
function PipelineMeshlet:new(indices, staticBounds, skinnedBounds)
	self.indices = indices
	self.staticBounds = staticBounds
	self.skinnedBounds = skinnedBounds or {}
	self.isSkinned = next(self.skinnedBounds) ~= nil

	self.skinnedBoundsByIndex = {}
	for _, bounds in pairs(self.skinnedBounds) do
		table.insert(self.skinnedBoundsByIndex, bounds)
	end
	table.sort(self.skinnedBoundsByIndex, _skinnedBoundsLess)
end

function PipelineMeshlet:getStaticBounds()
	return self.staticBounds.center, self.staticBounds.radius
end

function PipelineMeshlet:getIsSkinned()
	return self.isSkinned
end

function PipelineMeshlet:getSkinnedBoundsCount()
	return #self.skinnedBoundsByIndex
end

--- @param index any
--- @return RatScratch.Math.Vector3, number
function PipelineMeshlet:getSkinnedBoundsByIndex(index)
	local skinnedBounds = self.skinnedBoundsByIndex[index]
	if skinnedBounds then
		return skinnedBounds.center, skinnedBounds.radius
	end

	return self.staticBounds.center, self.staticBounds.radius
end

--- @param animation integer
--- @return RatScratch.Math.Vector3, number
function PipelineMeshlet:getSkinnedBounds(animation)
	local skinnedBounds = self.skinnedBounds[animation]
	if skinnedBounds then
		return skinnedBounds.center, skinnedBounds.radius
	end

	return self.staticBounds.center, self.staticBounds.radius
end

--- @param animation integer
--- @return integer
function PipelineMeshlet:getPrimaryBone(animation)
	local skinnedBounds = self.skinnedBounds[animation]
		or self.skinnedBounds[next(self.skinnedBounds)]
	if not skinnedBounds then
		return -1
	end

	return skinnedBounds.bone
end

--- @param index integer
--- @return integer
function PipelineMeshlet:getPrimaryBoneByIndex(index)
	local skinnedBounds = self.skinnedBoundsByIndex[index]
	if not skinnedBounds then
		return 0
	end

	return skinnedBounds.bone
end

--- @param index integer
--- @return integer
function PipelineMeshlet:getAnimationByIndex(index)
	local skinnedBounds = self.skinnedBoundsByIndex[index]
	if not skinnedBounds then
		return 0
	end

	return skinnedBounds.animation
end

--- @param meshletDefinition RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinition
--- @return RatScratch.Pipeline.Graphics3D.PipelineMeshlet
function PipelineMeshlet.fromDefinition(meshletDefinition)
	--- @type table<integer, RatScratch.Pipeline.Graphics3D.PipelineMeshletSkinnedBounds>
	local skinnedBounds
	if
		meshletDefinition.skinnedBounds
		and #meshletDefinition.skinnedBounds > 0
	then
		skinnedBounds = {}

		for _, bounds in ipairs(meshletDefinition.skinnedBounds) do
			skinnedBounds[bounds.animation] = {
				center = Vector3(unpack(bounds.center)),
				radius = bounds.radius,
				animation = bounds.animation,
				bone = bounds.bone,
			}
		end
	end

	local staticBounds = {
		center = Vector3(unpack(meshletDefinition.staticBounds.center)),
		radius = meshletDefinition.staticBounds.radius,
	}

	return PipelineMeshlet(
		meshletDefinition.indices,
		staticBounds,
		skinnedBounds
	)
end

return PipelineMeshlet
