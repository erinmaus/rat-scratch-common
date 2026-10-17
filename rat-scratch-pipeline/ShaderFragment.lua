local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.ShaderFragment : RatScratch.Common.BaseObject
--- @overload fun(source: string): RatScratch.Pipeline.ShaderFragment
local ShaderFragment = Object()

function ShaderFragment:new(source)
	self.source = source
end

function ShaderFragment:getSource()
	return self.source
end

return ShaderFragment
