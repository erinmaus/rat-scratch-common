local Math = require("rat-scratch-math")
local Table = require("rat-scratch-common").Table
local Point2D = Math.Geometry2D.Point
local Polygon2D = Math.Geometry2D.Polygon

local demo = require("samples.common.demo").new()

demo.polygons = {
	{ 100, 100, 200, 100, 250, 250, 100, 200 },
	{ 300, 300, 500, 300, 500, 500, 300, 500 },
}

demo.transforms = {
	love.math.newTransform(),
	love.math.newTransform(),
}

demo.polygonIndex = 1
demo.polygonPointIndex = -1
demo.isPolygonGrabbed = false

function demo.mousepressed(x, y, button)
	if button ~= 1 then
		return
	end

	demo.isPolygonGrabbed = false
	local bestPolygonDistance = math.huge

	for i, polygon in ipairs(demo.polygons) do
		local transformedPolygon =
			Polygon2D.transform(polygon, demo.transforms[i])

		for j = 1, #transformedPolygon, 2 do
			local px, py = transformedPolygon[j], transformedPolygon[j + 1]
			local distance = Point2D.distance(x, y, px, py)
			if distance < bestPolygonDistance then
				bestPolygonDistance = distance
				demo.polygonIndex = i
				demo.polygonPointIndex = Table.strideToIndex(j, 2)
			end
		end
	end

	if bestPolygonDistance > 16 then
		bestPolygonDistance = -math.huge

		for i, polygon in ipairs(demo.polygons) do
			local transformedPolygon =
				Polygon2D.transform(polygon, demo.transforms[i])

			if Polygon2D.isPointInside(x, y, transformedPolygon) then
				local _, _, _, distanceToPolygon =
					Polygon2D.pointDistance(x, y, transformedPolygon)

				if distanceToPolygon > bestPolygonDistance then
					bestPolygonDistance = distanceToPolygon
					demo.polygonIndex = i
					demo.polygonPointIndex = -1
				end
			end
		end

		demo.isPolygonGrabbed = bestPolygonDistance > 0
	else
		demo.isPolygonGrabbed = true
	end
end

function demo.mousemoved(x, y, dx, dy)
	if demo.isPolygonGrabbed then
		local polygon = demo.polygons[demo.polygonIndex]
		local numPoints = math.ceil(#polygon / 2)

		if
			demo.polygonPointIndex >= 1
			and demo.polygonPointIndex <= numPoints
		then
			local i = Table.indexToStride(demo.polygonPointIndex, 2)
			local px, py = polygon[i], polygon[i + 1]

			polygon[i], polygon[i + 1] = px + dx, py + dy

			if Polygon2D.isConcave(polygon) then
				polygon[i], polygon[i + 1] = px, py
			end
		else
			for i = 1, #polygon, 2 do
				polygon[i], polygon[i + 1] =
					polygon[i] + dx, polygon[i + 1] + dy
			end
		end
	end
end

function demo.mousereleased(x, y, button)
	if button == 1 then
		demo.isPolygonGrabbed = false
	end
end

function demo.update(deltaTime)
	if demo.isPolygonGrabbed then
		local rotation = 0

		if love.keyboard.isDown("left") then
			rotation = rotation - math.pi
		end

		if love.keyboard.isDown("right") then
			rotation = rotation + math.pi
		end

		local centerX, centerY = 0, 0
		local polygon = demo.polygons[demo.polygonIndex]
		for i = 1, #polygon, 2 do
			centerX, centerY = centerX + polygon[i], centerY + polygon[i + 1]
		end
		centerX = centerX / math.ceil(#polygon / 2)
		centerY = centerY / math.ceil(#polygon / 2)

		local transform = love.math.newTransform()
		transform:translate(centerX, centerY)
		transform:rotate(rotation * deltaTime)
		transform:translate(-centerX, -centerY)

		demo.polygons[demo.polygonIndex] =
			Polygon2D.transform(polygon, transform)
	end
end

function demo.drawPolygon(index)
	love.graphics.push()
	love.graphics.applyTransform(demo.transforms[index])
	love.graphics.polygon("line", demo.polygons[index])
	love.graphics.pop()
end

function demo.draw()
	demo.drawPolygon(1)
	demo.drawPolygon(2)
end

return demo
