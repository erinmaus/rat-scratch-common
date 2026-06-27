local Table = require("rat-scratch-common").Table
local Math = require("rat-scratch-math")
local BSPNode = Math.BSP2D.BSPNode
local Point = Math.Geometry2D.Point
local Polygon = Math.Geometry2D.Polygon

local demo = {}

demo.polygon = {}
demo.pendingSplit = {}
demo.polygonFinished = false

function demo.mousepressed(x, y, button)
	if button == 1 then
		if demo.polygonFinished then
			table.insert(demo.pendingSplit, x)
			table.insert(demo.pendingSplit, y)

			if #demo.pendingSplit == 4 then
				local node = demo.bsp:find(demo.pendingSplit[1], demo.pendingSplit[2]) or demo.bsp:find(demo.pendingSplit[3], demo.pendingSplit[4])
				if node then
					local nx, ny = Point.direction(demo.pendingSplit[1], demo.pendingSplit[2], demo.pendingSplit[3], demo.pendingSplit[4])

					node:split(demo.pendingSplit[1], demo.pendingSplit[2], nx, ny)
				end
				Table.clear(demo.pendingSplit)
			end
		else
			table.insert(demo.polygon, x)
			table.insert(demo.polygon, y)

			if #demo.polygon > 6 and not Polygon.isConvex(demo.polygon) then
				table.remove(demo.polygon)
				table.remove(demo.polygon)
			end
		end
	end
end

function demo.keypressed(_, scan, isRepeat)
	if scan == "space" then
		if not demo.polygonFinished then
			demo.polygonFinished = true
			demo.bsp = BSPNode(demo.polygon)
		end
	end
end

--- @param node RatScratch.Math.BSP2D.BSPNode
local function drawBSPNode(node)
	if node:getIsLeaf() then
		local mx, my = love.mouse.getPosition()
		if Polygon.isPointInside(mx, my, node:getPolygon()) then
			love.graphics.setColor(0, 1, 0, 1)
		else
			love.graphics.setColor(1, 1, 1, 0.25)
		end

		love.graphics.polygon("line", node:getPolygon())
	else
		for _, child in node:iterate() do
			drawBSPNode(child)
		end
	end
end

function demo.draw()
	love.graphics.push("all")
	love.graphics.setPointSize(2)
	love.graphics.setColor(1, 1, 1, 1)

	if demo.bsp then
		drawBSPNode(demo.bsp)
	elseif #demo.polygon > 2 then
		love.graphics.line(demo.polygon)
	else
		love.graphics.points(demo.polygon)
	end

	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.points(demo.pendingSplit)
	love.graphics.pop()
end

return demo
