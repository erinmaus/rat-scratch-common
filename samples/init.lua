local list = require("samples.common.list")

local function loadSamples()
	local samples = {}

	list.recurse("samples", function(path)
		if not path:match("/init%.lua$") and path:match("(.+)%.lua$") then
			table.insert(samples, path)
		end
	end)

	return samples
end

local samples = loadSamples()
local currentSample

function love.keypressed(key, scan, ...)
	if scan == "escape" then
		currentSample = nil
	end

	if currentSample and currentSample.keypressed then
		currentSample.keypressed(key, scan, ...)
	end
end

function love.keyreleased(...)
	if currentSample and currentSample.keyreleased then
		currentSample.keyreleased(...)
	end
end

function love.mousepressed(x, y, button, ...)
	if currentSample and currentSample.mousepressed then
		currentSample.mousepressed(x, y, button, ...)
	end
end

function love.mousereleased(x, y, button, ...)
	if currentSample and currentSample.mousereleased then
		currentSample.mousereleased(x, y, button, ...)
	elseif not currentSample and button == 1 then
		local index = list.click(samples, x, y)

		if index and samples[index] then
			currentSample = love.filesystem.load(samples[index])()
			
			if currentSample and currentSample.load then
				currentSample.load(arg)
			end
		end
	end
end

function love.mousemoved(...)
	if currentSample and currentSample.mousemoved then
		currentSample.mousemoved(...)
	end
end

function love.update(deltaTime)
	if currentSample and currentSample.update then
		currentSample.update(deltaTime)
	end
end

function love.draw()
	if currentSample and currentSample.draw then
		currentSample.draw()
	else
		local mx, my = love.mouse.getPosition()

		love.graphics.push("all")
		list.draw(samples)
		love.graphics.pop()
	end
end
