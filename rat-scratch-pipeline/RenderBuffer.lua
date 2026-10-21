local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Table = require("rat-scratch-common").Table

--- @alias RatScratch.Pipeline.RenderBuffer.CanvasPointer { renderBuffer: RatScratch.Pipeline.RenderBuffer, canvas: integer | "depth" }

--- @class RatScratch.Pipeline.RenderBuffer : RatScratch.Common.BaseObject
--- @field private width integer
--- @field private height integer
--- @field private layers integer
--- @field private format love.PixelFormat[]
--- @field private depthStencilFormat? love.PixelFormat
--- @field private depth? love.Texture
--- @field private canvases love.Texture[]
--- @field private binding table
--- @field private customBinding table
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

	self.format = Table.clone(format)
	self.depthStencilFormat = depth

	self.canvases = {}
	self.binding = { alllayers = true }
	self.customBinding = {}
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

function RenderBuffer:getDepthCanvas()
	return self.depth
end

function RenderBuffer:newCanvasPointer(index)
	return { renderBuffer = self, canvas = index }
end

function RenderBuffer:newDepthCanvasPointer()
	return { renderBuffer = self, canvas = "depth" }
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

	for i, format in ipairs(self.format) do
		if self.canvases[i] then
			self.canvases[i]:release()
		end

		local canvas = love.graphics.newTexture(width, height, layers, {
			type = "array",
			format = format,
			canvas = true,
			readable = true,
			mipmaps = "auto"
		})
		self.canvases[i] = canvas

		self.binding[i] = canvas
	end

	if self.depth then
		self.depth:release()
	end

	if self.depthStencilFormat then
		self.depth = love.graphics.newTexture(width, height, layers, {
			type = "array",
			format = self.depthStencilFormat,
			canvas = true,
			readable = true,
		})

		self.binding.depthstencil = self.depth
	end

	return true
end

--- @param canvases? integer[]
--- @param depth? boolean
function RenderBuffer:bind(canvases, depth)
	assert(#self.canvases > 0 or self.depth, "render buffer is not complete")

	local binding
	if canvases or depth then
		Table.clear(self.customBinding)
		self.customBinding.alllayers = true

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

		binding.alllayers = true
		love.graphics.setCanvas(binding)
	end
end

return RenderBuffer
