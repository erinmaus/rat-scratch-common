local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local ConstrainedSplitProfile =
	require("rat-scratch-dungeon.ConstrainedSplitProfile")

--- @class RatScratch.Dungeon.Navigator : RatScratch.Common.BaseObject
--- @field private pending RatScratch.Math.BSP2D.BSPNode[]
--- @field private currentNode? RatScratch.Math.BSP2D.BSPNode
--- @field private dungeon? RatScratch.Dungeon.Dungeon
--- @overload fun(): RatScratch.Dungeon.Navigator
local Navigator = Object()

function Navigator:new()
	self.pending = {}
end

--- @param root RatScratch.Math.BSP2D.BSPNode
--- @param dungeon RatScratch.Dungeon.Dungeon
function Navigator:start(root, dungeon)
	table.insert(self.pending, root)

	self.dungeon = dungeon
	self.currentNode = nil
end

--- @protected
--- @return RatScratch.Dungeon.Dungeon?
function Navigator:getDungeon()
	return self.dungeon
end

function Navigator:stop()
	Table.clear(self.pending)
	self.currentNode = nil
end

--- @return boolean
function Navigator:hasPending()
	return #self.pending > 0
end

--- @return RatScratch.Math.BSP2D.BSPNode?
--- @return RatScratch.Dungeon.ConstrainedSplitProfile?
function Navigator:next()
	if #self.pending == 0 then
		self.currentNode = nil
		return nil, nil
	end

	local node = table.remove(self.pending, 1)
	self.currentNode = node

	return node, self:generateSplitProfile(node)
end

--- @param profile? RatScratch.Dungeon.ConstrainedSplitProfile?
--- @param iteration? number
--- @return RatScratch.Dungeon.ConstrainedSplitProfile?
function Navigator:relax(profile, iteration)
	if not self.currentNode then
		return nil
	end

	iteration = iteration or 1
	profile = profile or self:generateSplitProfile(self.currentNode)

	return ConstrainedSplitProfile.relax(profile, iteration)
end

--- @protected
--- @param node RatScratch.Math.BSP2D.BSPNode
function Navigator:prepend(node)
	table.insert(self.pending, 1, node)
end

--- @protected
--- @param node RatScratch.Math.BSP2D.BSPNode
function Navigator:append(node)
	table.insert(self.pending, node)
end

--- @param node RatScratch.Math.BSP2D.BSPNode
--- @return RatScratch.Dungeon.ConstrainedSplitProfile
function Navigator:generateSplitProfile(node)
	return self:ABSTRACT()
end

--- @param parent RatScratch.Math.BSP2D.BSPNode
function Navigator:push(parent)
	self:ABSTRACT()
end

--- @generic T : table
--- @return T
function Navigator:serialize()
	return self:ABSTRACT()
end

--- @generic T : table
--- @param data T
function Navigator:deserialize(data)
	self:ABSTRACT()
end

return Navigator
