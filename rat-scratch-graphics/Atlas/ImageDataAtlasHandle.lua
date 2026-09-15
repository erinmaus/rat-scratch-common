local Object = require("rat-scratch-common").Object
local EventSource = require("rat-scratch-common").EventSource
local AtlasHandle = require("rat-scratch-graphics.Atlas.AtlasHandle")

--- @class RatScratch.Graphics.Atlas.ImageDataAtlasHandle : RatScratch.Graphics.Atlas.AtlasHandle
--- @overload fun(imageData?: love.ImageData): RatScratch.Graphics.Atlas.ImageDataAtlasHandle
--- @field private imageData? love.ImageData
local ImageDataAtlasHandle = Object(AtlasHandle)

function ImageDataAtlasHandle:new(imageData)
	AtlasHandle.new(self)

	self.imageData = imageData
end

function ImageDataAtlasHandle:getWidth()
	return self.imageData and self.imageData:getWidth() or 0
end

function ImageDataAtlasHandle:getHeight()
	return self.imageData and self.imageData:getHeight() or 0
end

function ImageDataAtlasHandle:setImageData(value)
	self.imageData = value
	self:fireModify()
end

--- @param texture love.Texture
--- @param layer integer
--- @param x integer
--- @param y integer
--- @param width integer
--- @param height integer
function ImageDataAtlasHandle:apply(texture, layer, x, y, width, height)
	if self.imageData then
		texture:replacePixels(self.imageData, layer, 1, x, y, false)
	end

	return true
end

return ImageDataAtlasHandle
