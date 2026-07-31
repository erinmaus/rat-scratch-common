local Object = require("rat-scratch-common").Object
local SkinnedModel = require("rat-scratch-graphics.Graphics3D.SkinnedModel")

--- @class RatScratch.Graphics.Pipeline3D.Instance : RatScratch.Common.BaseObject
--- @overload fun(pipeline: RatScratch.Graphics.Pipeline3D.Pipeline, model: RatScratch.Graphics.Graphics3D.Model): RatScratch.Graphics.Pipeline3D.Instance
--- @field private pipeline RatScratch.Graphics.Pipeline3D.Pipeline
--- @field private model RatScratch.Graphics.Graphics3D.Model
--- @field private isSkinned boolean
--- @field private transformsIndex integer
--- @field private transformsCount integer
local Instance = Object()

--- @param pipeline any
--- @param model RatScratch.Graphics.Graphics3D.Model
function Instance:new(pipeline, model)
	self.pipeline = pipeline
	self.model = model
	self.isSkinned = model:isDerived(SkinnedModel)
	self.transformsIndex = 0
	self.transformsCount = 0
end

function Instance:getIsSkinned()
	return self.isSkinned
end

function Instance:setTransformsIndexCount(index, count)
	self.transformsIndex = index
	self.transformsCount = count
end

function Instance:getTransformsIndexCount(index, count) end

return Instance
