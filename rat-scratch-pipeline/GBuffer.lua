local Object = require("rat-scratch-common").Object
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")

--- @class RatScratch.Pipeline.GBuffer : RatScratch.Pipeline.RenderBuffer
--- @overload fun(): RatScratch.Pipeline.GBuffer
local GBuffer = Object(RenderBuffer)

GBuffer.FORMAT = {
	"rgba8", -- albedo (rgb) + alpha mask (a)
	"rgba8", -- emissive (rgb) + alpha (heat)
	"rgb5a1", -- ultraviolet fluorescence (rgb) + alpha unused
	"rg16f", -- encoded normals
	"rgba8", -- metal, roughness, occlusion + alpha (material)
}

GBuffer.DEPTH_STENCIL_FORMAT = "depth32f"

function GBuffer:new()
	RenderBuffer.new(self, GBuffer.FORMAT, GBuffer.DEPTH_STENCIL_FORMAT)
end

return GBuffer
