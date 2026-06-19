local function attachDebugger()
	local isDebug = false

	for i = 2, #arg do
		if arg[i] == "/debug" or arg[i] == "--debug" then
			isDebug = true
		end
	end

	isDebug = isDebug and os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
	if isDebug then
		require("lldebugger").start()

		function love.errorhandler(msg)
			error(msg, 2)
		end
	end
end

attachDebugger()

local function recurse(path, func)
	if love.filesystem.getInfo(path, "directory") then
		local items = love.filesystem.getDirectoryItems(path)
		table.sort(items)

		for _, item in ipairs(items) do
			local itemPath = ("%s/%s"):format(path, item)
			recurse(itemPath, func)
		end
	elseif love.filesystem.getInfo(path, "file") then
		func(path)
	end
end

local function loadSamples()
	local samples = {}

	recurse("samples", function(path)
		table.insert(samples, path)
	end)

	return samples
end

local function inside(mx, my, x, y, width, height)
	return mx >= x and my >= y and mx <= x + width and my <= y + height
end

local function iterateSamples(samples, func)
	local font = love.graphics.getFont()

	local _, dh = love.graphics.getDimensions()

	local x = 8
	local y = 8
	local maxWidth = 0
	for i = 1, #samples do
		local width = font:getWidth(samples[i])
		local height = font:getHeight()

		maxWidth = math.max(maxWidth, width)

		local result = func(x, y, width, height, i, samples[i])
		if result ~= nil then
			return result
		end

		local ny = y + height + 8

		if ny > dh then
			x = maxWidth + 8
			y = 8
			maxWidth = 0
		else
			y = ny
		end
	end

	return nil
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
	elseif button == 1 then
		local index = iterateSamples(samples, function(sx, sy, sw, sh, i)
			if inside(x, y, sx, sy, sw, sh) then
				return i
			end
		end)

		if index and samples[index] then
			currentSample = love.filesystem.load(samples[index])()
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
		iterateSamples(samples, function(x, y, w, h, _, sample)
			if inside(mx, my, x, y, w, h) then
				love.graphics.setColor(0, 1, 1, 1)
			else
				love.graphics.setColor(1, 1, 1, 0.5)
			end

			love.graphics.print(sample, x, y)
		end)
		love.graphics.pop()
	end
end
