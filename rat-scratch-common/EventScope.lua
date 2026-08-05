local Object = require("rat-scratch-common.Object")

--- @class RatScratch.Common.EventScope : RatScratch.Common.BaseObject
--- @overload fun(name: string): RatScratch.Common.EventScope
--- @field private name string
local EventScope = Object()

function EventScope:new(name)
	self.name = name
end

function EventScope:getName()
	return self.name
end

--- @generic T
--- @param other T
function EventScope:is(other)
	return self:getType() == Object.getType(other)
end

--- @param name? string
--- @return RatScratch.Common.EventScope
function EventScope.create(name)
	if not name then
		local info = debug.getinfo(2, "Sl")
		local filename = info.source:match("@(.*)")

		if filename and love.filesystem.exists(filename) then
			local index = 1
			for line in love.filesystem.lines(filename) do
				if index == info.currentline then
					name = line:match(
						"%s*([%w_]+%.[%w_]+)%s*=%s*EventScope.create%b()"
					)

					if not name then
						local identifier = line:match(
							"%s*([%w_]+)%s*=%s*EventScope.create%b()"
						)
						local module = filename:match("/?([^./]+)%.?([^./]*)$")
						name = identifier
							and ("%s.%s"):format(module, identifier)
					end

					break
				end

				index = index + 1
			end
		end

		if not name then
			name = ("%s@%d"):format(info.short_src, info.currentline)
		end
	end

	return Object(name, 1)
end

return EventScope
