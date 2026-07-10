--- @class RatScratch.Dungeon.ConstrainedSplitProfile
--- @field public minAngle? number
--- @field public maxAngle? number
--- @field public angleRelaxationThreshold? number
--- @field public angleRelaxationFactor? number
--- @field public minEdgeLength? number
--- @field public maxEdgeLength? number
--- @field public edgeLengthRelaxationThreshold? number
--- @field public edgeLengthRelaxationFactor? number
--- @field public minArea? number
--- @field public maxArea? number
--- @field public areaRelaxationThreshold? number
--- @field public areaRelaxationFactor? number
local ConstrainedSplitProfile = {}

--- @param profile RatScratch.Dungeon.ConstrainedSplitProfile
--- @param iteration number
--- @return RatScratch.Dungeon.ConstrainedSplitProfile
function ConstrainedSplitProfile.relax(profile, iteration)
	if iteration == 0 then
		return profile
	end

	return {
		minAngle = profile.minAngle
				and (profile.minAngle - (profile.angleRelaxationThreshold or 0) * (profile.angleRelaxationFactor or 0) * iteration)
			or nil,
		maxAngle = profile.maxAngle
				and (profile.maxAngle + (profile.angleRelaxationThreshold or 0) * (profile.angleRelaxationFactor or 0) * iteration)
			or nil,
		angleRelaxationThreshold = profile.angleRelaxationThreshold,
		angleRelaxationFactor = profile.angleRelaxationFactor,
		minEdgeLength = profile.minEdgeLength
				and (profile.minEdgeLength - (profile.edgeLengthRelaxationThreshold or 0) * (profile.edgeLengthRelaxationFactor or 0) * iteration)
			or nil,
		maxEdgeLength = profile.maxEdgeLength
				and (profile.maxEdgeLength + (profile.edgeLengthRelaxationThreshold or 0) * (profile.edgeLengthRelaxationFactor or 0) * iteration)
			or nil,
		edgeLengthRelaxationThreshold = profile.edgeLengthRelaxationThreshold,
		edgeLengthRelaxationFactor = profile.edgeLengthRelaxationFactor,
		minArea = profile.minArea
				and (profile.minArea - (profile.areaRelaxationThreshold or 0) * (profile.areaRelaxationFactor or 0) * iteration)
			or nil,
		maxArea = profile.maxArea
				and (profile.maxArea + (profile.areaRelaxationThreshold or 0) * (profile.areaRelaxationFactor or 0) * iteration)
			or nil,
		areaRelaxationThreshold = profile.areaRelaxationThreshold,
		areaRelaxationFactor = profile.areaRelaxationFactor,
	}
end

return ConstrainedSplitProfile
