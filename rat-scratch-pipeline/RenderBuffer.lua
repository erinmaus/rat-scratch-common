local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Table = require("rat-scratch-common").Table

--- @alias RatScratch.Pipeline.RenderBuffer.CanvasPointer { renderBuffer: RatScratch.Pipeline.RenderBuffer, canvas: integer | "depth" }

--- @class RatScratch.Pipeline.RenderBuffer : RatScratch.Common.BaseObject
--- @field private width integer
--- @field private height integer
--- @field private layers integer
--- @field private mipmapCount integer
--- @field private format love.PixelFormat[]
--- @field private depthStencilFormat? love.PixelFormat
--- @field private depth? love.Texture
--- @field private canvases love.Texture[]
--- @field private canvasMipmapViews love.Texture[][]
--- @field private depthCanvasMipmapViews love.Texture[]
--- @field private binding table
--- @field private customBinding table
--- @field private minFilter string
--- @field private maxFilter string
--- @overload fun(format: love.PixelFormat[], depthStencilFormat?: love.PixelFormat): RatScratch.Pipeline.RenderBuffer
local RenderBuffer = Object()

--- @param format love.PixelFormat[]
--- @param depth? love.PixelFormat
function RenderBuffer:new(format, depth)
	assert(
		#format > 0 or depth,
		"render buffer must have at least one attachment"
	)

	self.width = 0
	self.height = 0
	self.layers = 0
	self.mipmapCount = 0

	self.format = Table.clone(format)
	self.depthStencilFormat = depth

	self.canvases = {}
	self.canvasMipmapViews = {}
	self.depthCanvasMipmapViews = {}
	self.binding = { shaderlayer = true }
	self.customBinding = {}

	self.minFilter = "nearest"
	self.maxFilter = "nearest"
end

function RenderBuffer:getWidth()
	return self.width
end

function RenderBuffer:getHeight()
	return self.height
end

function RenderBuffer:getLayers()
	return self.layers
end

function RenderBuffer:getMipmapCount()
	return self.mipmapCount
end

function RenderBuffer:getFormatCount()
	return #self.format
end

--- @param index integer
--- @return love.PixelFormat
function RenderBuffer:getFormat(index)
	return self.format[index]
end

function RenderBuffer:hasDepthStencilAttachment()
	return self.depthStencilFormat ~= nil
end

--- @return love.PixelFormat | "none"
function RenderBuffer:getDepthStencilAttachment()
	return self.depthStencilFormat or "none"
end

function RenderBuffer:getCanvasCount()
	return #self.canvases
end

--- @param index integer
--- @return love.Texture
function RenderBuffer:getCanvas(index)
	return self.canvases[index]
end

--- @param index integer
--- @param level integer
--- @return love.Texture
function RenderBuffer:getCanvasMipmap(index, level)
	return self.canvasMipmapViews[index]
		and self.canvasMipmapViews[index][level]
end

function RenderBuffer:getDepthCanvas()
	return self.depth
end

--- @param level integer
--- @return love.Texture
function RenderBuffer:getDepthCanvasMipmap(level)
	return self.depthCanvasMipmapViews[level]
end

function RenderBuffer:newCanvasPointer(index)
	return { renderBuffer = self, canvas = index }
end

function RenderBuffer:newDepthCanvasPointer()
	return { renderBuffer = self, canvas = "depth" }
end

function RenderBuffer:_applyFilter()
	for _, canvas in ipairs(self.canvases) do
		canvas:setFilter(self.minFilter, self.maxFilter)
	end

	for _, mipmaps in ipairs(self.canvasMipmapViews) do
		for _, mipmap in ipairs(mipmaps) do
			mipmap:setFilter(self.minFilter, self.maxFilter)
		end
	end

	if self.depthCanvas then
		self.depthCanvas:setFilter(self.minFilter, self.maxFilter)
	end

	for _, mipmap in ipairs(self.depthCanvasMipmapViews) do
		mipmap:setFilter(self.minFilter, self.maxFilter)
	end
end

function RenderBuffer:setFilter(minFilter, maxFilter)
	minFilter = minFilter or "nearest"
	maxFilter = maxFilter or minFilter

	self.minFilter = minFilter
	self.maxFilter = maxFilter

	self:_applyFilter()
end

--- @param width? integer
--- @param height? integer
--- @param layers? integer
--- @return boolean
function RenderBuffer:resize(width, height, layers)
	width, height =
		math.floor(width or love.graphics.getWidth()),
		math.floor(height or love.graphics.getHeight())
	width, height = math.max(width, 1), math.max(height, 1)
	layers = math.max(math.floor(layers or 1), 1)

	if
		width == self.width
		and height == self.height
		and layers <= self.layers
	then
		return false
	end

	self.width = width
	self.height = height
	self.layers = layers
	self.mipmapCount = 1
		+ math.floor(math.log(math.max(self.width, self.height), 2))

	for i, format in ipairs(self.format) do
		if self.canvasMipmapViews[i] then
			for _, view in ipairs(self.canvasMipmapViews[i]) do
				view:release()
			end

			Table.clear(self.canvasMipmapViews[i])
		end

		if self.canvases[i] then
			self.canvases[i]:release()
		end

		--- @type love.Texture
		local canvas = love.graphics.newTexture(width, height, layers, {
			type = "array",
			format = format,
			canvas = true,
			readable = true,
			computewrite = true,
			mipmaps = "manual",
		})
		self.canvases[i] = canvas

		local mipmapViews = self.canvasMipmapViews[i] or {}
		self.canvasMipmapViews[i] = mipmapViews
		for j = 1, canvas:getMipmapCount() do
			mipmapViews[j] = love.graphics.newTextureView(canvas, {
				mipmapstart = j,
				mipmapcount = 1,
			})
		end

		self.binding[i] = canvas
	end

	for _, view in ipairs(self.depthCanvasMipmapViews) do
		view:release()
	end
	Table.clear(self.depthCanvasMipmapViews)

	if self.depth then
		self.depth:release()
	end

	if self.depthStencilFormat then
		self.depth = love.graphics.newTexture(width, height, layers, {
			type = "array",
			format = self.depthStencilFormat,
			canvas = true,
			readable = true,
			mipmaps = "manual",
		})

		for i = 1, self.depth:getMipmapCount() do
			self.depthCanvasMipmapViews[i] =
				love.graphics.newTextureView(self.depth, {
					mipmapstart = i,
					mipmapcount = 1,
				})
		end

		self.binding.depthstencil = self.depth
	end

	self:_applyFilter()

	return true
end

function RenderBuffer:generateCanvasMipmaps(index)
	if self.canvases[index] then
		self.canvases[index]:generateMipmaps()
	end
end

function RenderBuffer:generateDepthMipmaps()
	if self.depth then
		self.depth:generateMipmaps()
	end
end

function RenderBuffer:generateMipmaps()
	for _, canvas in ipairs(self.canvases) do
		canvas:generateMipmaps()
	end

	if self.depth then
		self.depth:generateMipmaps()
	end
end

--- @param canvases? integer[]
--- @param depth? boolean
function RenderBuffer:bind(canvases, depth)
	assert(#self.canvases > 0 or self.depth, "render buffer is not complete")

	local binding
	if canvases or depth then
		Table.clear(self.customBinding)
		self.customBinding.shaderlayer = true

		if canvases then
			for _, index in ipairs(canvases) do
				assert(
					index >= 1 and index <= #self.canvases,
					"index %d out of range; must be > 1 and < %d",
					index,
					#canvases
				)

				table.insert(self.customBinding, self.canvases[index])
			end
		end

		if depth and self:hasDepthStencilAttachment() then
			self.customBinding.depthstencil = self.depth
		end

		binding = self.customBinding
	else
		binding = self.binding
	end

	love.graphics.setCanvas(binding)
end

do
	local _binding = {}

	--- @param ... RatScratch.Pipeline.RenderBuffer.CanvasPointer
	function RenderBuffer.multibind(...)
		local binding = _binding
		Table.clear(binding)

		for i = 1, select("#", ...) do
			--- @type RatScratch.Pipeline.RenderBuffer.CanvasPointer
			local pointer = select(i, ...)

			if pointer.canvas == "depth" then
				assert(
					not _binding.depthstencil,
					"cannot bind multiple depth/stencil buffers"
				)

				_binding.depthstencil = pointer.renderBuffer:getDepthCanvas()
			else
				local index = pointer.canvas

				--- @cast index integer
				binding[i] = pointer.renderBuffer:getCanvas(index)
			end
		end

		binding.shaderlayer = true
		love.graphics.setCanvas(binding)
	end
end

return RenderBuffer
