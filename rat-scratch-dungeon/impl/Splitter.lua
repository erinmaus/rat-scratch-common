local Object = require("rat-scratch-common").Object
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table
local FlatTable = require("rat-scratch-common").FlatTable
local Point = require("rat-scratch-math").Geometry2D.Point
local Common = require("rat-scratch-math").Common
local Polygon = require("rat-scratch-math").Geometry2D.Polygon

--- @class RatScratch.Dungeon.impl.Splitter : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Dungeon.impl.Splitter
local Splitter = Object()

function Splitter:new()
	-- initialize cache data structures

	self.inputPolygonWrapper = FlatTable.wrap(0, 2)

	self.outputPolygon = {}
	self.outputPolygonWrapper = FlatTable.wrap(0, 2)

	self.outputPolygonEdgeLengths = {}
	self.outputPolygonEdgeLengthsWrapper = FlatTable.wrap(0, 1)

	self.outputPolygonDirections = {}
	self.outputPolygonDirectionWrapper = FlatTable.wrap(0, 2)

	self.outputPolygonNormals = {}
	self.outputPolygonNormalsWrapper = FlatTable.wrap(0, 2)

	self.outputPolygonExtents = {}
	self.outputPolygonExtentsWrapper = FlatTable.wrap(0, 2)

	self.outputPolygonProtectedEdge = {}
	self.outputPolygonProtectedEdgeWrapper = FlatTable.wrap(0, 1)

	--- @param a integer
	--- @param b integer
	self._compareEdge = function(a, b)
		local ax1, ax2 = self.outputPolygonExtentsWrapper:get(a)
		local bx1, bx2 = self.outputPolygonExtentsWrapper:get(b)

		local x1 = Common.zerosign(ax1 - bx1)
		if x1 == 0 then
			return Common.zerosign(ax2 - bx2)
		end

		return x1
	end

	--- @param a integer
	--- @param b integer
	self._less = function(a, b)
		return self._compareEdge(a, b) < 0
	end

	self.sweptEdges = {}
end

--- @private
--- @param points number[]
--- @param connections RatScratch.Dungeon.impl.Connections
function Splitter:_splitEdges(points, connections)
	local isClockwise = Polygon.isClockwise(points)

	local outputPolygon = self.outputPolygon
	local outputPolygonEdgeLengths = self.outputPolygonEdgeLengths
	local outputPolygonDirections = self.outputPolygonDirections
	local outputPolygonNormals = self.outputPolygonNormals
	local outputPolygonExtents = self.outputPolygonExtents
	local outputPolygonProtectedEdge = self.outputPolygonProtectedEdge

	Table.clear(outputPolygon)
	Table.clear(outputPolygonEdgeLengths)
	Table.clear(outputPolygonDirections)
	Table.clear(outputPolygonNormals)
	Table.clear(outputPolygonExtents)
	Table.clear(outputPolygonProtectedEdge)

	local inputPolygon = self.inputPolygonWrapper:intrude(points)

	for i = 1, inputPolygon:getLength() do
		local x1, y1 = inputPolygon:get(i)
		local x2, y2 = inputPolygon:get(i + 1)

		local dx, dy = Point.direction(x1, y1, x2, y2)
		local edgeLength = Point.length(dx, dy)
		local nx, ny

		if edgeLength > 0 then
			local reciprocalEdgeLength = 1 / edgeLength
			nx, ny = dx * reciprocalEdgeLength, dy * reciprocalEdgeLength
		else
			nx, ny = 0, 0
		end

		Table.append(outputPolygon, x1, y1)

		local px = x1
		local previousDelta = 0
		local edgeCount = 1
		local connectionCount = connections:getConnectionsCount(i)
		for j = 1, connectionCount do
			local connectionStart, connectionStop =
				connections:getConnection(i, j)

			if connectionStart == connectionStop then
				local pointDelta = connectionStart
				if
					Common.greaterThan(pointDelta, previousDelta)
					and Common.lessThan(pointDelta, 1)
				then
					local sx = x1 + nx * pointDelta * edgeLength
					local sy = y1 + ny * pointDelta * edgeLength
					local splitEdgeLength = (pointDelta - previousDelta)
						* edgeLength

					Table.append(outputPolygon, sx, sy)
					Table.append(outputPolygonEdgeLengths, splitEdgeLength)
					Table.append(
						outputPolygonExtents,
						math.min(px, sx),
						math.max(px, sx)
					)
					Table.append(outputPolygonProtectedEdge, false)

					edgeCount = edgeCount + 1
					px = sx
				end

				previousDelta = pointDelta
			else
				if Common.greaterThan(connectionStart, previousDelta) then
					local sx = x1 + nx * connectionStart * edgeLength
					local sy = y1 + ny * connectionStart * edgeLength
					local splitEdgeLength = (connectionStart - previousDelta)
						* edgeLength

					Table.append(outputPolygon, sx, sy)
					Table.append(outputPolygonEdgeLengths, splitEdgeLength)
					Table.append(
						outputPolygonExtents,
						math.min(px, sx),
						math.max(px, sx)
					)
					Table.append(outputPolygonProtectedEdge, false)

					edgeCount = edgeCount + 1
					px = sx
				end

				if Common.lessThan(connectionStop, 1) then
					local sx = x1 + nx * connectionStop * edgeLength
					local sy = y1 + ny * connectionStop * edgeLength
					local splitEdgeLength = (connectionStop - connectionStart)
						* edgeLength

					Table.append(outputPolygon, sx, sy)
					Table.append(outputPolygonEdgeLengths, splitEdgeLength)
					Table.append(
						outputPolygonExtents,
						math.min(px, sx),
						math.max(px, sx)
					)
					Table.append(outputPolygonProtectedEdge, true)

					edgeCount = edgeCount + 1
					px = sx
				end

				previousDelta = connectionStop
			end
		end

		local finalDelta = 1 - previousDelta
		if Common.greaterThan(finalDelta, 0) then
			Table.append(outputPolygonEdgeLengths, finalDelta * edgeLength)
			Table.append(
				outputPolygonExtents,
				math.min(px, x2),
				math.max(px, x2)
			)

			local isLastEdgeProtected = Common.greaterThan(previousDelta, 1)
			Table.append(outputPolygonProtectedEdge, isLastEdgeProtected)
		end

		local tx, ty
		if isClockwise then
			tx, ty = Point.left(nx, ny)
		else
			tx, ty = Point.right(nx, ny)
		end

		for _ = 1, edgeCount do
			Table.append(outputPolygonDirections, nx, ny)
			Table.append(outputPolygonNormals, tx, ty)
		end
	end

	self.outputPolygonWrapper:intrude(outputPolygon)
	self.outputPolygonEdgeLengthsWrapper:intrude(outputPolygonEdgeLengths)
	self.outputPolygonDirectionWrapper:intrude(outputPolygonDirections)
	self.outputPolygonNormalsWrapper:intrude(outputPolygonNormals)
	self.outputPolygonExtentsWrapper:intrude(outputPolygonExtents)
	self.outputPolygonProtectedEdgeWrapper:intrude(outputPolygonProtectedEdge)
end

--- @private
--- @param node RatScratch.Math.BSP2D.BSPNode
--- @param connections RatScratch.Dungeon.impl.Connections
function Splitter:start(node, connections)
	self:_splitEdges(node:getPolygon(), connections)
end

function Splitter:split()
	-- TODO
end

return Splitter
