local Object = require("rat-scratch-common").Object

--- @class RatScratch.Dungeon.impl.Connections : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Dungeon.impl.Connections
local Connections = Object()

function Connections:new() end

--- @param edgeIndex integer
function Connections:getConnectionsCount(edgeIndex)
	return 0
end

--- @param edgeIndex integer
--- @param connectionIndex integer
--- @return number, number
function Connections:getConnection(edgeIndex, connectionIndex)
	return 0, 0
end

--- @param edgeIndex integer
--- @param connectionIndex integer
--- @return integer
function Connections:getConnectionID(edgeIndex, connectionIndex)
	return 0
end

return Connections
