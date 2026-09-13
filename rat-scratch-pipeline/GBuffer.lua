local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.GBuffer : RatScratch.Common.BaseObject
--- @field private width integer
--- @field private height integer
--- @field private layers integer
--- @field private canvases love.Texture[]
--- @field private depth love.Texture
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.GBuffer
local GBuffer = Object()

GBuffer.FORMAT = {
	"rgba8", -- albedo (rgb) + alpha mask (a)
	"rgb5a1", -- emissive (rgb) + alpha unused
	"rgb5a1", -- ultraviolet fluorescence (rgb) + alpha unused
	"rg16f", -- rg16f (encoded normals)
	"rgba8", -- rgba8 (metal, roughness, occlusion) + alpha unused
	"r8", -- r8 (material)
}

GBuffer.DEPTH_STENCIL_FORMAT = "depth32f"

function GBuffer:new()
	self.width = 0
	self.height = 0
	self.layers = 0

	self.canvases = {}
	self.binding = {}
end

function GBuffer:getWidth()
	return self.width
end

function GBuffer:getHeight()
	return self.height
end

function GBuffer:getLayers()
	return self.layers
end

--- @param width? integer
--- @param height? integer
--- @param layers? integer
--- @return boolean
function GBuffer:resize(width, height, layers)
	width, height =
		math.floor(width or love.graphics.getWidth()),
		math.floor(height or love.graphics.getHeight())
	width, height = math.max(width, 1), math.max(height, 1)
	layers = math.max(math.floor(layers or 1), 1)

	if
		not (
			width == self.width
			and height == self.height
			and layers == self.layers
		)
	then
		return false
	end

	self.width = width
	self.height = height
	self.layers = layers

	for i, format in ipairs(GBuffer.FORMAT) do
		if self.canvases[i] then
			self.canvases[i]:release()
		end

		local binding = self.binding[i]
		if not binding then
			binding = {}
			self.binding[i] = binding
		end

		local canvas = love.graphics.newTexture(width, height, layers, {
			type = "array",
			format = format,
			canvas = true,
			readable = true,
		})
		self.canvases[i] = canvas

		binding[1] = canvas

		-- TODO: enable layer rendered
		if self.layers == 1 then
			binding.layer = 1
		end
	end

	if self.depth then
		self.depth:release()
	end

	self.depth = love.graphics.newTexture(width, height, layers, {
		type = "array",
		format = GBuffer.DEPTH_STENCIL_FORMAT,
		canvas = true,
		readable = true,
	})

	self.binding.depthstencil = self.depth

	return true
end

function GBuffer:bind()
	love.graphics.setCanvas(self.binding)
end

return GBuffer
