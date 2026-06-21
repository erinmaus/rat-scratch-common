local Math = require("rat-scratch-math")
local Table = require("rat-scratch-common").Table
local SAT2D = Math.Geometry2D.SAT

local demo = love.filesystem.load("samples/math/polygon.lua")()

function demo.draw()
	local isCollision, nx, ny, distance, meta = SAT2D.project(demo.polygons[1], demo.polygons[2], demo.transforms[1], demo.transforms[2], nil, nil, {})

    love.graphics.push("all")

	if isCollision and meta then
		local halfDistance = math.abs(distance) / 2

		love.graphics.push()
		love.graphics.translate(nx * halfDistance, ny * halfDistance)
		demo.drawPolygon(1)
		love.graphics.pop()
		
		love.graphics.push()
		love.graphics.translate(nx * -halfDistance, ny * -halfDistance)
		demo.drawPolygon(2)
		love.graphics.pop()
	end

	love.graphics.setLineWidth(2)

	demo.drawPolygon(1)
	demo.drawPolygon(2)

	if isCollision and meta then
		love.graphics.setLineWidth(1)

		local polygon = meta.polygon
		local pi1 = Table.indexToStride(meta.edge, 2)
		local pj1 = pi1 + 1
		local pi2 = Table.wrapIndex(pi1 + 2, #polygon)
		local pj2 = pi2 + 1
		love.graphics.setColor(1, 0, 0, 1)
		love.graphics.line(polygon[pi1], polygon[pj1], polygon[pi2], polygon[pj2])

		local otherPolygon = meta.polygon == demo.polygons[1] and demo.polygons[2] or demo.polygons[1]
		local oi1 = Table.indexToStride(meta.otherEdge, 2)
		local oj1 = oi1 + 1
		local oi2 = Table.wrapIndex(oi1 + 2, #otherPolygon)
		local oj2 = oi2 + 1

		love.graphics.setColor(0, 1, 1, 1)
		love.graphics.line(otherPolygon[oi1], otherPolygon[oj1], otherPolygon[oi2], otherPolygon[oj2])
	end

	love.graphics.print(string.format("normal: (%f, %f), depth: %f", nx, ny, distance), 10, 10)
	love.graphics.pop()
end

return demo
