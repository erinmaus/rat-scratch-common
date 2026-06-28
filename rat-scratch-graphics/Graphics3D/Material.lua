local Object = require("rat-scratch-common").Object

--- @class RatScratch.Graphics.Graphics3D.Material : RatScratch.Common.BaseObject
--- @overload fun(texture?: love.graphics.Texture, color?: number[]): RatScratch.Graphics.Graphics3D.Material
--- @field private texture? love.graphics.Texture
--- @field private color number[]
local Material = Object()

--- @param texture? love.graphics.Texture
--- @param color? number[]
function Material:new(texture, color)
	local outputColor
	if not color then
		outputColor = { 1, 1, 1, 1 }
	else
		outputColor = { unpack(color, 1, 4) }
	end

	self.texture = texture
	self.color = outputColor
end

--- @return love.graphics.Texture
function Material:getTexture()
	return self.texture
end

--- @return number, number, number, number
function Material:getColor()
	local r, g, b, a = unpack(self.color)
	return r, g, b, a
end

return Material
