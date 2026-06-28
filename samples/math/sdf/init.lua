require("love.image")
require("love.timer")

local SDF = require("rat-scratch-math").Geometry2D.SDF

local id, w, h, polygons = ...

local imageData = love.image.newImageData(w, h, "rgba8")
local before = love.timer.getTime()
imageData:mapPixel(function(x, y)
	--local distance = SDF.distanceFromPolygons(x, y, polygons)
	local distance = SDF.distanceFromCircle(x, y, 100, 100, 40)
	local value = math.min(math.abs(distance / 255), 1)
	if distance < 0 then
		return 0, value, 0, 1
	else
		return value, value, value, 1
	end
end)
local after = love.timer.getTime()

local outputChannel = love.thread.getChannel("::sdf")

outputChannel:push({
	id = id,
	image = imageData,
	time = (after - before) * 1000,
})
