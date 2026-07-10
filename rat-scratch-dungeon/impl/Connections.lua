local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert

--- @class RatScratch.Dungeon.impl.Connections : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Dungeon.impl.Connections
--- @field connections table<integer, number[][]>
--- @field connectionIDs table<integer, integer[]>
--- @field edgesByID table<integer, integer>
local Connections = Object()

function Connections:new()
	self.connections = {}
	self.connectionIDs = {}
	self.edgesByID = {}
end

--- @param edgeIndex integer
--- @param connectionID integer
--- @param startDelta number
--- @param stopDelta number
function Connections:addConnection(
	edgeIndex,
	connectionID,
	startDelta,
	stopDelta
)
	assert(
		startDelta <= stopDelta,
		"edge %d (id = %d): start delta (%f) must be less than or equal to stop delta (%f)",
		edgeIndex,
		connectionID,
		startDelta,
		stopDelta
	)

	assert(
		startDelta >= 0 and stopDelta <= 1,
		"edge %d (id = %d): start delta (%f) must be greater than or equal to zero and stop delta (%f) must be less than or equal to 1",
		edgeIndex,
		connectionID,
		startDelta,
		stopDelta
	)

	local edgeConnections = self.connections[edgeIndex]
	if not edgeConnections then
		edgeConnections = {}
		self.connections[edgeIndex] = edgeConnections
	end

	local edgeConnectionIDs = self.connectionIDs[edgeIndex]
	if not edgeConnectionIDs then
		edgeConnectionIDs = {}
		self.connectionIDs[edgeIndex] = edgeConnectionIDs
	end

	local index
	for i, edgeConnection in ipairs(edgeConnections) do
		index = i

		local otherStartDelta, otherStopDelta =
			edgeConnection[1], edgeConnection[2]
		if stopDelta > otherStartDelta and startDelta < otherStopDelta then
			assert(
				false,
				"edge %d: provided start delta (%f) / stop delta (%f) overlaps connection %d",
				edgeIndex,
				startDelta,
				stopDelta,
				i
			)
			break
		end

		if startDelta >= otherStopDelta then
			local nextEdgeConnection = edgeConnections[i + 1]
			if nextEdgeConnection then
				local nextStartDelta, nextStopDelta =
					nextEdgeConnection[1], nextEdgeConnection[2]
				assert(
					stopDelta < nextStartDelta or startDelta > nextStopDelta,
					"edge %d: provided start delta (%f) / stop delta (%f) overlaps connection %d",
					edgeIndex,
					startDelta,
					stopDelta,
					i + 1
				)
			end
		end
	end

	assert(
		not self.edgesByID[connectionID],
		"connection ID %d already belongs to edge %d",
		connectionID,
		self.edgesByID[connectionID]
	)

	table.insert(edgeConnections, (index or 0) + 1, { startDelta, stopDelta })
	table.insert(edgeConnectionIDs, (index or 0) + 1, connectionID)
	self.edgesByID[connectionID] = edgeIndex
end

--- @param edgeIndex integer
function Connections:getConnectionsCount(edgeIndex)
	local edgeConnections = self.connections[edgeIndex]
	return edgeConnections and #edgeConnections or 0
end

--- @param edgeIndex integer
--- @param connectionIndex integer
--- @return number, number
function Connections:getConnection(edgeIndex, connectionIndex)
	local edgeConnections = self.connections[edgeIndex]
	local edgeConnection = edgeConnections and edgeConnections[connectionIndex]

	assert(
		edgeConnection,
		"edge %d does not have a connection at index %d",
		edgeIndex,
		connectionIndex
	)

	return edgeConnection[1], edgeConnection[2]
end

--- @param edgeIndex integer
--- @param connectionIndex integer
--- @return integer
function Connections:getConnectionID(edgeIndex, connectionIndex)
	local edgeConnectionIDs = self.connectionIDs[edgeIndex]
	local connectionID = edgeConnectionIDs
		and edgeConnectionIDs[connectionIndex]

	assert(
		connectionID,
		"edge %d does not have a connection at index %d",
		edgeIndex,
		connectionIndex
	)

	return connectionID
end

return Connections
