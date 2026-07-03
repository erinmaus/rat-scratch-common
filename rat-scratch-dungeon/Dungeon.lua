local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local BSPNode = require("rat-scratch-math").BSP2D.BSPNode

--- @class RatScratch.Dungeon.Dungeon : RatScratch.Common.BaseObject
--- @overload fun(definition: RatScratch.Dungeon.DungeonDefinition): RatScratch.Dungeon.Dungeon
--- @field navigator RatScratch.Dungeon.Navigator
--- @field rootBSPNode RatScratch.Math.BSP2D.BSPNode
--- @field limits RatScratch.Dungeon.DungeonDefinition.Limits
local Dungeon = Object()

--- @param definition RatScratch.Dungeon.DungeonDefinition
function Dungeon:new(definition)
	self.navigator = definition.navigator

	self.limits = {
		attemptSplitIterations = definition.limits
				and definition.limits.attemptSplitIterations
			or 5,
	}

	self:_initBSPNode(definition.shape)
end

function Dungeon:generate()
	self.navigator:start(self.rootBSPNode, self)

	while self.navigator:hasPending() do
		local node, profile = self.navigator:next()
		assert(node and profile, "navigator has pending but next returned nil")

		local iterationCount = 0
		local currentProfile = profile
		while iterationCount <= self.limits.attemptSplitIterations do
			if self:_solveNodeSplit(node, currentProfile) then
				self.navigator:push(node)
				break
			end

			iterationCount = iterationCount + 1
			local nextProfile = self.navigator:relax(profile, iterationCount)
			if not nextProfile then
				break
			end

			currentProfile = nextProfile
		end
	end
end

--- @private
--- @param node RatScratch.Math.BSP2D.BSPNode
--- @param profile RatScratch.Dungeon.ConstrainedSplitProfile
function Dungeon:_solveNodeSplit(node, profile) end

--- @private
--- @param node RatScratch.Math.BSP2D.BSPNode
--- @return RatScratch.Dungeon.impl.Connections
function Dungeon:_getNodeConnections(node)
	return {}
end

--- @private
--- @param shape RatScratch.Dungeon.DungeonDefinition.RootShape
function Dungeon:_initBSPNode(shape)
	if shape.type == "bsp" then
		self.rootBSPNode = shape.node:clone()
	elseif shape.type == "polygon" then
		self.rootBSPNode = BSPNode(shape.points)
	elseif shape.type == "rectangle" then
		self.rootBSPNode = BSPNode({
			shape.x or 0,
			shape.y or 0,
			(shape.x or 0) + shape.width,
			shape.y or 0,
			(shape.x or 0) + shape.width,
			(shape.y or 0) + shape.height,
			shape.x or 0,
			(shape.y or 0) + shape.height,
		})
	end
end

return Dungeon
