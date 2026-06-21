local Math = require("rat-scratch-math")
local Minkowski2D = Math.Geometry2D.Minkowski

local demo = love.filesystem.load("samples/math/polygon.lua")()

function demo.draw()
	local isCollision, nx, ny, distance = Minkowski2D.difference(demo.polygons[1], demo.polygons[2], demo.transforms[1], demo.transforms[2])

    local polygon = Minkowski2D.getLastDebugMinkowskiPolygon()
    if #polygon >= 6 then
        local w, h = love.graphics.getDimensions()
        love.graphics.push("all")
        love.graphics.translate(w / 2, h / 2)
		love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.polygon("fill", polygon)
        love.graphics.pop()
    end

    love.graphics.push("all")
	love.graphics.setLineWidth(2)

	demo.drawPolygon(1)

    if isCollision then
        love.graphics.setColor(1, 0, 0, 1)
    else
        love.graphics.setColor(0, 1, 0, 1)
    end
    demo.drawPolygon(2)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print(string.format("normal: (%f, %f), depth: %f", nx, ny, distance), 10, 10)
	love.graphics.pop()
end

return demo
