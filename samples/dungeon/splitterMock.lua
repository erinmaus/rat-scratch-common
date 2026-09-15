local Table = require("rat-scratch-common").Table
local Random = require("rat-scratch-dungeon").Random
local Common = require("rat-scratch-math").Common
local BSPNode = require("rat-scratch-math").BSP2D.BSPNode
local Connections = require("rat-scratch-dungeon.impl.Connections")
local Point = require("rat-scratch-math").Geometry2D.Point
local Polygon = require("rat-scratch-math").Geometry2D.Polygon
local Splitter = require("rat-scratch-dungeon.impl.Splitter")

local demo = {}

demo.count = 0
function demo.newRNG()
	demo.count = demo.count + 1
	return love.math.newRandomGenerator(demo.count)
end

demo.splitter = Splitter()

--- @class RatScratch.Samples.Dungeon.SplitterMockRandom : RatScratch.Dungeon.Random
--- @overload fun(): RatScratch.Samples.Dungeon.SplitterMockRandom
local DemoRandom = Random.extend()

function DemoRandom:new()
	self.edge = { 1 }
	self.edgeIndex = 1
end

function DemoRandom:setEdge(...)
	self.edge = { ... }
	self.edgeIndex = 1
end

function DemoRandom:rollEdge(min, max)
	local index = Table.wrapIndex(self.edgeIndex, #self.edge)
	local edgeIndex = self.edge[index]
	local result = (edgeIndex - 1) % (max - min + 1) + min

	self.edgeIndex = self.edgeIndex + 1

	return result
end

function demo.generateConnections(count)
	local rng = demo.newRNG()

	local connections = Connections()

	local n = rng:random(count - 2)
	local id = 1
	local visited = {}

	for _ = 1, n do
		local edgeIndex = rng:random(n)
		if not visited[edgeIndex] then
			local connectionCount = math.max(rng:random(5) - 2, 1)

			local previousStop = 0
			for _ = 1, connectionCount do
				local start = previousStop + rng:random() * 0.25
				local stop = start + rng:random() * 0.125 + 0.125

				connections:addConnection(
					edgeIndex,
					id,
					start,
					math.min(stop, 1)
				)
				id = id + 1

				if stop >= 1 then
					break
				end

				previousStop = stop
			end

			visited[edgeIndex] = true
		end
	end

	demo.split(demo.polygon, connections)

	return connections
end

function demo.generatePolygon(winding, offset, count)
	local sign = 1
	if winding == "cw" then
		sign = -1
	end

	local rng = demo.newRNG()

	local radius = math.min(love.graphics.getDimensions()) / 2
	local halfRadius = radius / 2

	local polygon = {}

	local step = math.pi * 2 / count
	local halfStep = step / 2
	local currentAngle = offset * sign
	for i = 1, count do
		local r = rng:random(halfRadius, radius)
		local x = love.graphics.getWidth() / 2 + math.cos(currentAngle) * r
		local y = love.graphics.getHeight() / 2 + math.sin(currentAngle) * r

		currentAngle = currentAngle
			+ ((rng:random() * halfStep) + halfStep) * sign

		Table.append(polygon, x, y)
	end

	if not Polygon.isConvex(polygon) then
		return demo.generatePolygon(winding, offset, count)
	end

	if winding == "cw" then
		return Polygon.reverseOrder(polygon)
	end

	return polygon
end

function demo.split(polygon, connections)
	demo.splitter = Splitter()

	local node = BSPNode(polygon)
	demo.splitter:start(node, connections)
end

local font = love.graphics.newFont(16)
function demo.mousemoved(x, y)
	if
		not (
			demo.currentEdge >= 1
			and demo.currentEdge
				<= (demo.splitter.outputPolygonWrapper:getLength())
		)
	then
		return
	end

	local x1, y1 = demo.splitter.outputPolygonWrapper:get(demo.currentEdge)
	local x2, y2 = demo.splitter.outputPolygonWrapper:get(demo.currentEdge + 1)
	local cx, cy = Common.lerp(x1, x2, 0.5), Common.lerp(y1, y2, 0.5)
	local dx, dy = Point.direction(cx, cy, x, y)

	local angle = Common.wrapAngle(math.atan2(dy, dx))
	local range = math.pi / 32

	--- @type RatScratch.Dungeon.ConstrainedSplitProfile
	local profile = {
		minAngle = Common.wrapAngle(angle - range),
		maxAngle = Common.wrapAngle(angle + range),
	}

	demo.minAngle = profile.minAngle
	demo.maxAngle = profile.maxAngle

	demo.split(demo.polygon, demo.connections)
	demo.projection = demo.splitter:projectEdgeWithAngles(
		demo.currentEdge,
		profile.minAngle,
		profile.maxAngle
	)
	demo.polygons = demo.splitter:projectEdgeWithAnglesAndConnections(
		demo.currentEdge,
		profile.minAngle,
		profile.maxAngle
	)
end

function demo.keypressed(key, scan, isRepeat)
	if isRepeat then
		return
	end

	local c = tonumber(key)
	if c and c >= 3 then
		demo.polygon = demo.generatePolygon(demo.winding, math.pi / 2, c)
		demo.connections = demo.generateConnections(c)
		return
	end

	if key == "w" then
		if demo.winding == "cw" then
			demo.winding = "ccw"
		elseif demo.winding == "ccw" then
			demo.winding = "cw"
		end

		demo.polygon = Polygon.reverseOrder(demo.polygon)
		demo.split(demo.polygon, demo.connections)
		demo.currentEdge = -1

		return
	end

	if key == "c" then
		demo.connections = demo.generateConnections(#demo.polygon / 2)
		demo.currentEdge = -1
		return
	end

	if key == "x" then
		demo.connections = Connections()
	end

	if key == "e" and #demo.splitter.outputPolygon >= 6 then
		local mx, my = love.mouse.getPosition()
		local _, _, _, edge =
			Polygon.pointDistance(mx, my, demo.splitter.outputPolygon)

		demo.currentEdge = edge
		return
	end

	if key == "space" then
		if demo.minAngle and demo.maxAngle then
			for i = 1, 8 do
				local node = BSPNode(demo.polygon)
				local splitter = Splitter()
				splitter:start(node, demo.connections)
				local success, x, y, nx, ny = splitter:split({
					minAngle = demo.minAngle,
					maxAngle = demo.maxAngle,
				}, Random())

				if success and x and y and nx and ny then
					node:split(x, y, nx, ny)
					demo.splitNode = node
					break
				end
			end
		end

		return
	end
end

demo.winding = "cw"
demo.polygon = demo.generatePolygon(demo.winding, math.pi / 2, 6)
demo.connections = demo.generateConnections(6)
demo.polygons = {}
demo.currentEdge = -1

function demo.draw()
	love.graphics.push("all")
	love.graphics.setFont(font)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.polygon("line", demo.polygon)

	if demo.splitNode then
		love.graphics.setLineWidth(2)
		love.graphics.setColor(0, 1, 1, 0.5)

		for _, child in demo.splitNode:iterate() do
			love.graphics.polygon("line", child:getPolygon())
		end

		love.graphics.setLineWidth(1)
	end

	if demo.projection then
		love.graphics.setColor(1, 1, 1, 0.25)
		love.graphics.polygon("fill", demo.projection)
	end

	for i = 1, #demo.polygons do
		if #demo.polygons[i] >= 6 then
			love.graphics.setColor(1, 1, 1, 0.25)
			love.graphics.polygon("fill", demo.polygons[i])

			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.polygon("line", demo.polygons[i])
		end
	end

	love.graphics.setLineWidth(4)
	love.graphics.setPointSize(8)

	if
		demo.currentEdge >= 1
		and demo.currentEdge
			<= demo.splitter.outputPolygonWrapper:getLength()
	then
		local x1, y1 = demo.splitter.outputPolygonWrapper:get(demo.currentEdge)
		local x2, y2 =
			demo.splitter.outputPolygonWrapper:get(demo.currentEdge + 1)

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.line(x1, y1, x2, y2)
	end

	for i = 1, #demo.polygon, 2 do
		local j = i + 1
		local k = Table.wrapIndex(j + 1, #demo.polygon)
		local l = k + 1

		local x1, y1 = demo.polygon[i], demo.polygon[j]
		local x2, y2 = demo.polygon[k], demo.polygon[l]

		local edgeIndex = (i - 1) / 2 + 1

		for n = 1, demo.connections:getConnectionsCount(edgeIndex) do
			local startDelta, stopDelta =
				demo.connections:getConnection(edgeIndex, n)

			local cx1, cy1 =
				Common.lerp(x1, x2, startDelta), Common.lerp(y1, y2, startDelta)
			local cx2, cy2 =
				Common.lerp(x1, x2, stopDelta), Common.lerp(y1, y2, stopDelta)

			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.line(cx1, cy1, cx2, cy2)
			love.graphics.points(cx1, cy1, cx2, cy2)
		end
	end

	if demo.splitter then
		for i = 1, demo.splitter.outputPolygonWrapper:getLength() do
			local x1, y1 = demo.splitter.outputPolygonWrapper:get(i)
			local x2, y2 = demo.splitter.outputPolygonWrapper:get(i + 1)
			local s = tostring(i)
			local x, y =
				Common.lerp(x1, x2, 0.5) - font:getWidth(s) / 2,
				Common.lerp(y1, y2, 0.5) - font:getHeight() / 2
			love.graphics.setColor(0, 0, 0, 1)
			love.graphics.print(s, x + 2, y + 2)
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(s, x, y)
		end
	end

	if demo.minAngle and demo.maxAngle then
		local x, y = 64, 64

		love.graphics.setColor(0, 1, 0, 0.25)
		love.graphics.circle("fill", x, y, 32)

		if demo.minAngle == demo.maxAngle then
			local x1, y1 =
				x + math.cos(demo.minAngle) * 32,
				y + math.sin(demo.minAngle) * 32

			love.graphics.setLineWidth(1)
			love.graphics.setColor(0, 1, 0, 1)
			love.graphics.line(x, y, x1, y1)
		else
			local x1, y1 =
				x + math.cos(demo.minAngle) * 32,
				y + math.sin(demo.minAngle) * 32
			local x2, y2 =
				x + math.cos(demo.maxAngle) * 32,
				y + math.sin(demo.maxAngle) * 32

			love.graphics.setLineWidth(1)
			love.graphics.setColor(0, 1, 1, 1)
			love.graphics.line(x, y, x1, y1)
			love.graphics.print("min", x1, y1)
			love.graphics.setColor(1, 0, 1, 1)
			love.graphics.line(x, y, x2, y2)
			love.graphics.print("max", x2, y2)
		end

		love.graphics.setColor(0, 1, 0, 1)
		love.graphics.circle("line", x, y, 32)
	end

	love.graphics.pop()
end

return demo
