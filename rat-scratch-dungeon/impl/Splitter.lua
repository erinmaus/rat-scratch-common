local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Table = require("rat-scratch-common").Table
local TablePool = require("rat-scratch-common").TablePool
local FlatTable = require("rat-scratch-common").FlatTable
local Point = require("rat-scratch-math").Geometry2D.Point
local Common = require("rat-scratch-math").Common
local Polygon = require("rat-scratch-math").Geometry2D.Polygon
local Line = require("rat-scratch-math").Geometry2D.Line
local Contour = require("rat-scratch-math").Geometry2D.Contour

--- @class RatScratch.Dungeon.impl.Splitter : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Dungeon.impl.Splitter
--- @field polygonPool RatScratch.Common.TablePool<number[]>
--- @field tablePool RatScratch.Common.TablePool<table>
--- @field inputPolygonWrapper RatScratch.Common.FlatTable<number>
--- @field outputPolygon number[]
--- @field outputPolygonWrapper RatScratch.Common.FlatTable<number>
--- @field outputPolygonEdgeLengths number[]
--- @field outputPolygonEdgeLengthsWrapper RatScratch.Common.FlatTable<number>
--- @field outputPolygonDirections number[]
--- @field outputPolygonDirectionsWrapper RatScratch.Common.FlatTable<number>
--- @field outputPolygonNormals number[]
--- @field outputPolygonNormalsWrapper RatScratch.Common.FlatTable<number>
--- @field outputPolygonProtectedEdge boolean[]
--- @field outputPolygonProtectedEdgeWrapper RatScratch.Common.FlatTable<number>
--- @field workingPolygonWrapper RatScratch.Common.FlatTable<number>
--- @field polygonWinding "cw" | "ccw"
local Splitter = Object()

function Splitter:new()
	self.inputPolygonWrapper = FlatTable.wrap(0, 2)

	self.outputPolygon = {}
	self.outputPolygonWrapper = FlatTable.wrap(0, 2)

	self.outputPolygonEdgeLengths = {}
	self.outputPolygonEdgeLengthsWrapper = FlatTable.wrap(0, 1)

	self.outputPolygonDirections = {}
	self.outputPolygonDirectionsWrapper = FlatTable.wrap(0, 2)

	self.outputPolygonNormals = {}
	self.outputPolygonNormalsWrapper = FlatTable.wrap(0, 2)

	self.outputPolygonProtectedEdge = {}
	self.outputPolygonProtectedEdgeWrapper = FlatTable.wrap(0, 1)

	self.polygonPool = TablePool()
	self.tablePool = TablePool()

	self.workingPolygonWrapper = FlatTable.wrap(0, 2)
end

--- @private
--- @param points number[]
--- @param connections RatScratch.Dungeon.impl.Connections
function Splitter:_splitEdges(points, connections)
	self.polygonWinding = Polygon.winding(points)

	local outputPolygon = self.outputPolygon
	local outputPolygonEdgeLengths = self.outputPolygonEdgeLengths
	local outputPolygonDirections = self.outputPolygonDirections
	local outputPolygonNormals = self.outputPolygonNormals
	local outputPolygonProtectedEdge = self.outputPolygonProtectedEdge

	Table.clear(outputPolygon)
	Table.clear(outputPolygonEdgeLengths)
	Table.clear(outputPolygonDirections)
	Table.clear(outputPolygonNormals)
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

			local isLastEdgeProtected = Common.greaterThan(previousDelta, 1)
			Table.append(outputPolygonProtectedEdge, isLastEdgeProtected)
		end

		local tx, ty
		if self.polygonWinding == "cw" then
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
	self.outputPolygonDirectionsWrapper:intrude(outputPolygonDirections)
	self.outputPolygonNormalsWrapper:intrude(outputPolygonNormals)
	self.outputPolygonProtectedEdgeWrapper:intrude(outputPolygonProtectedEdge)
end

--- @param node RatScratch.Math.BSP2D.BSPNode
--- @param connections RatScratch.Dungeon.impl.Connections
function Splitter:start(node, connections)
	self.polygonPool:reset()
	self.tablePool:reset()

	self:_splitEdges(node:getPolygon(), connections)
end

--- @private
--- @param polygon RatScratch.Common.FlatTable<number>
--- @param polygonDirections RatScratch.Common.FlatTable<number>
--- @param edgeIndex integer
--- @param anx number
--- @param any number
--- @param bnx number
--- @param bny number
--- @return boolean, number, number, boolean, number, number
function Splitter:_calculateEdgeRayDirections(
	polygon,
	polygonDirections,
	edgeIndex,
	anx,
	any,
	bnx,
	bny
)
	local x1, y1 = polygon:get(edgeIndex)
	local x2, y2 = polygon:get(edgeIndex + 1)

	local dx, dy
	if polygonDirections then
		dx, dy = polygonDirections:get(edgeIndex)
	else
		dx, dy = Point.directionNormal(x1, y1, x2, y2)
	end

	if self.polygonWinding == "ccw" then
		anx, bnx = bnx, anx
		any, bny = bny, any
	end

	local d1 = Line.direction(x1, y1, x1 + dx, y1 + dy, x1 + anx, y1 + any)
	local d2 = Line.direction(x2, y2, x2 + dx, y2 + dy, x2 + bnx, y2 + bny)

	local inside1 = Polygon.isOnSide(self.polygonWinding, "inside", d1)
	local inside2 = Polygon.isOnSide(self.polygonWinding, "inside", d2)

	return inside1, anx, any, inside2, bnx, bny
end

--- @private
--- @param edgeIndex integer
--- @param minAngle number
--- @param maxAngle number
--- @return boolean, number[]?, integer?, integer?
function Splitter:_projectEdge(edgeIndex, minAngle, maxAngle)
	local anx, any = math.cos(minAngle), math.sin(minAngle)
	local bnx, bny = math.cos(maxAngle), math.sin(maxAngle)

	local inside1, dx1, dy1, inside2, dx2, dy2 =
		self:_calculateEdgeRayDirections(
			self.outputPolygonWrapper,
			self.outputPolygonDirectionsWrapper,
			edgeIndex,
			anx,
			any,
			bnx,
			bny
		)

	local x1, y1 = self.outputPolygonWrapper:get(edgeIndex)
	local x2, y2 = self.outputPolygonWrapper:get(edgeIndex + 1)

	if not (inside1 or inside2) then
		return true,
			self.outputPolygon,
			1,
			self.outputPolygonWrapper:getLength()
	end

	local destinationPolygon = self.polygonPool:pop()
	local sourcePolygon = self.polygonPool:pop()

	Table.clear(destinationPolygon)
	Table.clear(sourcePolygon)

	local outputPolygon = self.outputPolygon
	local workingPolygon = outputPolygon
	local index1, index2

	if inside1 then
		local left, right
		if self.polygonWinding == "cw" then
			left, right = sourcePolygon, destinationPolygon
		else
			left, right = destinationPolygon, sourcePolygon
		end

		-- we 'linecast' into the original output polygon to get the intersection index of the first ray
		-- this will later be used to fine protected edges and perform further splits
		local _, _, _, _, j =
			Polygon.linecast(x1, y1, x1 + dx1, y1 + dy1, outputPolygon)

		Polygon.split(
			x1,
			y1,
			x1 + dx1,
			y1 + dy1,
			workingPolygon,
			nil,
			left,
			right
		)
		index1 = j

		if #destinationPolygon < 6 then
			return false
		end

		workingPolygon = destinationPolygon
	end

	destinationPolygon = self.polygonPool:pop()
	sourcePolygon = self.polygonPool:pop()

	if inside2 then
		local left, right
		if self.polygonWinding == "cw" then
			left, right = destinationPolygon, sourcePolygon
		else
			left, right = sourcePolygon, destinationPolygon
		end

		-- again, we linecast into the original output polygon to get the 'range' of vertices intersected;
		-- this will be used to iterate over protected edges in the output polygon
		local _, _, _, _, j =
			Polygon.linecast(x2, y2, x2 + dx2, y2 + dy2, outputPolygon)
		index2 = j

		Polygon.split(
			x2,
			y2,
			x2 + dx2,
			y2 + dy2,
			workingPolygon,
			nil,
			left,
			right
		)

		if #destinationPolygon < 6 then
			return false
		end

		workingPolygon = destinationPolygon
	end

	local startIndex, stopIndex
	if index1 and index2 then
		startIndex = index2
		stopIndex = index1
	elseif not (index1 or index2) then
		startIndex = 1
		stopIndex = self.outputPolygonWrapper:getLength()
	else
		startIndex = index2 or edgeIndex
		stopIndex = index1 or edgeIndex
	end

	return true, workingPolygon, startIndex, stopIndex
end

--- @private
--- @param x number
--- @param y number
--- @param dx number
--- @param dy number
--- @param side "left" | "right"
--- @return number[] | nil
function Splitter:_splitOutputPolygonByLine(x, y, dx, dy, side, polygon)
	local left = self.polygonPool:pop()
	local right = self.polygonPool:pop()

	local _, _, _, i, j =
		Polygon.split(x, y, x + dx, y + dy, polygon, nil, left, right)
	if i or j then
		if side == "left" and #left >= 6 then
			return left
		elseif side == "right" and #right >= 6 then
			return right
		end
	end

	return nil
end

--- @private
--- @param edgeIndex integer
--- @param anx number
--- @param any number
--- @param bnx number
--- @param bny number
--- @param polygon number[][]
--- @return number[][]
function Splitter:_splitOutputPolygonByConstraintEdgeProjection(
	edgeIndex,
	anx,
	any,
	bnx,
	bny,
	polygon
)
	local inside1, dx1, dy1, inside2, dx2, dy2 =
		self:_calculateEdgeRayDirections(
			self.outputPolygonWrapper,
			self.outputPolygonDirectionsWrapper,
			edgeIndex,
			-anx,
			-any,
			-bnx,
			-bny
		)

	local result = self.tablePool:pop()

	if not (inside1 or inside2) then
		Table.append(result, polygon)
		return result
	end

	local x1, y1 = self.outputPolygonWrapper:get(edgeIndex)
	local x2, y2 = self.outputPolygonWrapper:get(edgeIndex + 1)

	local a
	if inside1 then
		a = self:_splitOutputPolygonByLine(
			x1,
			y1,
			dx1,
			dy1,
			self.polygonWinding == "cw" and "left" or "right",
			polygon
		)
	end

	local b
	if inside2 then
		b = self:_splitOutputPolygonByLine(
			x2,
			y2,
			dx2,
			dy2,
			self.polygonWinding == "cw" and "right" or "left",
			polygon
		)
	end

	local first, second = a or b, a and b
	Table.append(result, first, second)

	return result
end

--- @private
--- @param polygon number[]
--- @param minAngle number
--- @param maxAngle number
--- @param startIndex integer
--- @param stopIndex integer
function Splitter:_splitWorkingPolygonByConnections(
	polygon,
	minAngle,
	maxAngle,
	startIndex,
	stopIndex
)
	local outputPolygons = self.tablePool:pop()
	table.insert(outputPolygons, polygon)

	local ianx, iany = math.cos(minAngle), math.sin(minAngle)
	local ibnx, ibny = math.cos(maxAngle), math.sin(maxAngle)
	local outputPolygonProtectedEdges = self.outputPolygonProtectedEdgeWrapper
	local length = outputPolygonProtectedEdges:getLength()

	for i = 1, length do
		local index = Table.wrapIndex(startIndex + i - 1, length)

		local isProtected = outputPolygonProtectedEdges:get(index)
		if isProtected then
			local nextOutputPolygons = self.tablePool:pop()

			for _, polygon in ipairs(outputPolygons) do
				local polygons =
					self:_splitOutputPolygonByConstraintEdgeProjection(
						index,
						ianx,
						iany,
						ibnx,
						ibny,
						polygon
					)

				Table.append(nextOutputPolygons, unpack(polygons))
			end

			outputPolygons = nextOutputPolygons
		end

		if index == stopIndex then
			break
		end
	end

	return outputPolygons
end

--- @param edgeIndex integer
--- @param minAngle number
--- @param maxAngle number
--- @return number[]?
function Splitter:projectEdgeWithAngles(edgeIndex, minAngle, maxAngle)
	local _, projectedPolygon = self:_projectEdge(edgeIndex, minAngle, maxAngle)
	return projectedPolygon
end

--- @param edgeIndex integer
--- @param minAngle number
--- @param maxAngle number
--- @return number[][]
function Splitter:projectEdgeWithAnglesAndConnections(
	edgeIndex,
	minAngle,
	maxAngle
)
	local success, projectedPolygon, i, j =
		self:_projectEdge(edgeIndex, minAngle, maxAngle)

	local resultPolygons
	if success and projectedPolygon and i and j then
		resultPolygons = self:_splitWorkingPolygonByConnections(
			projectedPolygon,
			minAngle,
			maxAngle,
			i,
			j
		)
	end

	return resultPolygons or self.tablePool:pop()
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @private
	--- @param outputPolygon number[]
	--- @param edgeIndex integer
	--- @param outputPolygonEdgeIndex? integer
	--- @return boolean, integer?
	function Splitter:_findCollinearEdgeIndex(
		outputPolygon,
		edgeIndex,
		outputPolygonEdgeIndex
	)
		local polygon = wrappedPolygon:intrude(outputPolygon)

		local x1, y1 = self.outputPolygonWrapper:get(edgeIndex)
		local x2, y2 = self.outputPolygonWrapper:get(edgeIndex + 1)

		for i = outputPolygonEdgeIndex or 1, polygon:getLength() do
			local x3, y3 = polygon:get(i)
			local x4, y4 = polygon:get(i + 1)

			if Line.isCollinear(x1, y1, x2, y2, x3, y3, x4, y4) then
				return true, i
			end
		end

		return false, nil
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @private
	--- @param profile RatScratch.Dungeon.ConstrainedSplitProfile
	--- @param splitPolygon number[]
	function Splitter:_isWithinConstraints(profile, splitPolygon)
		local simplifiedSplitPolygon =
			Contour.simplify(splitPolygon, nil, nil, self.polygonPool:pop())
		local polygon = wrappedPolygon:intrude(simplifiedSplitPolygon)

		if profile.minEdgeLength or profile.maxEdgeLength then
			local minEdgeLength = math.max(profile.minEdgeLength or 0, 0)
			local maxEdgeLength =
				math.max(profile.maxEdgeLength or math.huge, 0)

			for i = 1, polygon:getLength() do
				local x1, y1 = polygon:get(i)
				local x2, y2 = polygon:get(i + 1)
				local length = Point.distance(x1, y1, x2, y2)
				if length < minEdgeLength or length > maxEdgeLength then
					return false
				end
			end
		end

		if profile.minArea or profile.maxArea then
			local minArea = math.max(profile.minArea, 0)
			local maxArea = math.max(profile.maxArea or math.huge, 0)

			local area = Polygon.area(simplifiedSplitPolygon)
			if area < minArea or area > maxArea then
				return false
			end
		end

		return true
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @private
	--- @param profile RatScratch.Dungeon.ConstrainedSplitProfile
	--- @param random RatScratch.Dungeon.Random
	--- @param outputPolygon number[]
	--- @param outputEdgeIndex integer
	--- @return boolean, number?, number?, number?, number?
	function Splitter:_trySplitEdge(
		profile,
		random,
		outputPolygon,
		outputEdgeIndex
	)
		local polygon = wrappedPolygon:intrude(outputPolygon)

		local x1, y1 = polygon:get(outputEdgeIndex)
		local x2, y2 = polygon:get(outputEdgeIndex + 1)
		local delta = random:rollEdgeDelta()

		local x, y = Common.lerp(x1, x2, delta), Common.lerp(y1, y2, delta)
		local angle = random:rollAngle(profile.minAngle, profile.maxAngle)
		local nx, ny = math.cos(angle), math.sin(angle)

		local left = self.polygonPool:pop()
		local right = self.polygonPool:pop()
		local success =
			Polygon.split(x, y, x + nx, y + ny, outputPolygon, nil, left, right)
		if not success then
			return false
		end

		if
			not (
				self:_isWithinConstraints(profile, left)
				and self:_isWithinConstraints(profile, right)
			)
		then
			return false
		end

		return true, x, y, nx, ny
	end
end

--- @private
--- @param profile RatScratch.Dungeon.ConstrainedSplitProfile
--- @param random RatScratch.Dungeon.Random
--- @param edgeIndex integer
--- @param outputPolygons number[][]
--- @return boolean, number?, number?, number?, number?
function Splitter:_trySplit(profile, random, edgeIndex, outputPolygons)
	for _, outputPolygon in ipairs(outputPolygons) do
		local success, outputEdgeIndex =
			self:_findCollinearEdgeIndex(outputPolygon, edgeIndex)
		while success and outputEdgeIndex do
			local success, x, y, nx, ny = self:_trySplitEdge(
				profile,
				random,
				outputPolygon,
				outputEdgeIndex
			)

			if success then
				return true, x, y, nx, ny
			end

			success, outputEdgeIndex = self:_findCollinearEdgeIndex(
				outputPolygon,
				edgeIndex,
				outputEdgeIndex + 1
			)
		end
	end

	return false
end

--- @param profile RatScratch.Dungeon.ConstrainedSplitProfile
--- @param random RatScratch.Dungeon.Random
--- @return boolean, number?, number?, number?, number?
function Splitter:split(profile, random)
	local minAngle, maxAngle = profile.minAngle, profile.maxAngle
	minAngle = Common.wrapAngle(minAngle or 0)
	maxAngle = Common.wrapAngle(maxAngle or math.pi * 2)

	minAngle, maxAngle =
		math.min(minAngle, maxAngle), math.max(minAngle, maxAngle)

	local offset = random:rollEdge(1, self.outputPolygonWrapper:getLength())
	for i = 1, self.outputPolygonWrapper:getLength() do
		local edgeIndex = i + offset - 1

		local outputPolygons = self:projectEdgeWithAnglesAndConnections(
			edgeIndex,
			minAngle,
			maxAngle
		)
		local success, x, y, nx, ny =
			self:_trySplit(profile, random, edgeIndex, outputPolygons)

		if success then
			return true, x, y, nx, ny
		end
	end

	return false
end

return Splitter
