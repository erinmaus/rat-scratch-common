local Table = require("rat-scratch-common").Table
local SDF = require("rat-scratch-math").Geometry2D.SDF
local Polygon = require("rat-scratch-math").Geometry2D.Polygon
local MarchingSquares = require("rat-scratch-math").MarchingSquares

local demo = require("samples.common.demo").new("samples/common/polygon/init.lua")

local function sampleSDF(polygons, x, y)
	local sample = SDF.distanceFromPolygons(x, y, polygons) - 8
	return sample, sample < 0
end

function demo.keypressed(_, scan, isRepeat)
	if scan == "space" and not isRepeat then
		local polygons = {
			Polygon.transform(demo.polygons[1], demo.transforms[1]),
			Polygon.reverseOrder(Polygon.transform(demo.polygons[2], demo.transforms[2])),
		}

		local before = love.timer.getTime()
		demo.contours = MarchingSquares.generate(0, 0, love.graphics.getWidth(), love.graphics.getHeight(), 20, polygons, sampleSDF)
		local after = love.timer.getTime()
		
		demo.time = (after - before) * 1000
	end
end

function demo.draw()
	if demo.current then
		love.graphics.draw(demo.current.texture)
	end

	local transformedPolygons = {
		Polygon.transform(demo.polygons[1], demo.transforms[1]),
		Polygon.reverseOrder(Polygon.transform(demo.polygons[2], demo.transforms[2])),
	}

	local mx, my = love.mouse.getPosition()
	local distance = SDF.distanceFromPolygons(mx, my, transformedPolygons)
	local isCollision = distance <= 0

	love.graphics.push("all")
	if isCollision then
		love.graphics.setColor(1, 0, 0, 1)
	else
		love.graphics.setColor(0, 1, 0, 1)
	end

	demo.drawPolygon(1)
	demo.drawPolygon(2)

	love.graphics.setColor(1, 1, 1, 1)
	if demo.contours then
		for _, contour in ipairs(demo.contours) do
			for i = 1, #contour, 4 do
				local j = i + 2--Table.wrapIndex(i + 2, #contour)
				local x1, y1 = unpack(contour, i, i + 1)
				local x2, y2 = unpack(contour, j, j + 1)

				love.graphics.line(x1, y1, x2, y2)
			end
		end
	end

	love.graphics.pop()

	love.graphics.print(("polygon distance: %f"):format(distance), 8, 8)

	if demo.contours then
		love.graphics.print(("- time to generate marching squares: %f ms (%d contours)"):format(demo.time, #demo.contours), 8, 32)
	end
end

return demo
