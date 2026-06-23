local list = {}

function list.recurse(path, func)
	if love.filesystem.getInfo(path, "directory") then
		local items = love.filesystem.getDirectoryItems(path)
		table.sort(items)

		for _, item in ipairs(items) do
			local itemPath = ("%s/%s"):format(path, item)
			list.recurse(itemPath, func)
		end
	elseif love.filesystem.getInfo(path, "file") then
		func(path)
	end
end

function list.inside(mx, my, x, y, width, height)
	return mx >= x and my >= y and mx <= x + width and my <= y + height
end

function list.iterate(values, func)
	local font = love.graphics.getFont()

	local _, dh = love.graphics.getDimensions()

	local x = 8
	local y = 8
	local maxWidth = 0
	for i = 1, #values do
		local width = font:getWidth(values[i])
		local height = font:getHeight()

		maxWidth = math.max(maxWidth, width)

		local result = func(x, y, width, height, i, values[i])
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

function list.click(values, mx, my)
	return list.iterate(values, function(sx, sy, sw, sh, i)
		if list.inside(mx, my, sx, sy, sw, sh) then
			return i
		end
	end)
end

function list.draw(values)
	local mx, my = love.mouse.getPosition()

	list.iterate(values, function(x, y, w, h, _, sample)
		if list.inside(mx, my, x, y, w, h) then
			love.graphics.setColor(0, 1, 1, 1)
		else
			love.graphics.setColor(1, 1, 1, 0.5)
		end

		love.graphics.print(tostring(sample), x, y)
	end)
end

return list
