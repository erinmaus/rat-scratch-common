local SDF = require("rat-scratch-math").Geometry2D.SDF
local Polygon = require("rat-scratch-math").Geometry2D.Polygon

local demo = require("samples.common.demo").new("samples/common/polygon/init.lua")

demo.threads = {}
demo.waiting = 0

function demo.keypressed(_, scan, isRepeat)
	local thread = love.thread.newThread("samples/math/sdf/init.lua")

	thread:start(#demo.threads + 1, love.graphics.getWidth(), love.graphics.getHeight(), {
		Polygon.transform(demo.polygons[1], demo.transforms[1]),
		Polygon.reverseOrder(Polygon.transform(demo.polygons[2], demo.transforms[2])),
	})

	table.insert(demo.threads, thread)
	demo.waiting = demo.waiting + 1
end

function demo.update()
	if demo.waiting == 0 then
		return
	end

	local inputChannel = love.thread.getChannel("::sdf")
	local e = inputChannel:pop()

	if e and (not demo.current or e.id >= demo.current.id) then
		demo.current = {
			id = e.id,
			texture = love.graphics.newTexture(e.image),
			time = e.time
		}

		demo.waiting = demo.waiting - 1
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

	love.graphics.pop()

	love.graphics.print(("polygon distance: %f"):format(distance), 8, 8)

	if demo.current then
		love.graphics.print(("- time to generate SDF texture: %f ms"):format(demo.current.time), 8, 32)
	end
end

return demo
