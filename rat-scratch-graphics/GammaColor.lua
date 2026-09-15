local Object = require("rat-scratch-common").Object
local Common = require("rat-scratch-math").Common

--- @class RatScratch.Graphics.GammaColor : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Graphics.GammaColor
--- @overload fun(c: number): RatScratch.Graphics.GammaColor
--- @overload fun(r: number, g: number, b: number): RatScratch.Graphics.GammaColor
--- @overload fun(r: number, g: number, b: number, a: number): RatScratch.Graphics.GammaColor
--- @overload fun(c: number, a: number): RatScratch.Graphics.GammaColor
local GammaColor = Object()

function GammaColor:new(r, g, b, a)
	self:from(r, g, b, a)
end

--- @return number, number, number, number
function GammaColor:get()
	return self.r, self.g, self.b, self.a
end

--- @overload fun(self: RatScratch.Graphics.GammaColor): RatScratch.Graphics.GammaColor
--- @overload fun(self: RatScratch.Graphics.GammaColor, c: number): RatScratch.Graphics.GammaColor
--- @overload fun(self: RatScratch.Graphics.GammaColor, r: number, g: number, b: number): RatScratch.Graphics.GammaColor
--- @overload fun(self: RatScratch.Graphics.GammaColor, r: number, g: number, b: number, a: number): RatScratch.Graphics.GammaColor
--- @overload fun(self: RatScratch.Graphics.GammaColor, c: number, a: number): RatScratch.Graphics.GammaColor
--- @return RatScratch.Graphics.GammaColor
function GammaColor:from(c1, c2, c3, c4)
	local r, g, b, a
	if c1 and c2 and c3 and c4 then
		r = c1
		g = c2
		b = c3
		a = c4
	elseif c1 and c2 and c3 then
		r = c1
		g = c2
		b = c3
		a = 1
	elseif c1 and c2 then
		r = c1
		g = c1
		b = c1
		a = c2
	else
		r = 1
		g = 1
		b = 1
		a = 1
	end

	self.r = r
	self.g = g
	self.b = b
	self.a = a

	return self
end

--- @param result? RatScratch.Graphics.GammaColor
--- @return RatScratch.Graphics.GammaColor
function GammaColor:saturate(result)
	result = result or GammaColor()
	return result:from(
		Common.saturate(self.r),
		Common.saturate(self.g),
		Common.saturate(self.b),
		Common.saturate(self.a)
	)
end

--- @overload fun(color: RatScratch.Graphics.GammaColor?): RatScratch.Graphics.GammaColor
--- @overload fun(color: RatScratch.Graphics.GammaColor?, c: number): RatScratch.Graphics.GammaColor
--- @overload fun(color: RatScratch.Graphics.GammaColor?, r: number, g: number, b: number): RatScratch.Graphics.GammaColor
--- @overload fun(color: RatScratch.Graphics.GammaColor?, r: number, g: number, b: number, a: number): RatScratch.Graphics.GammaColor
--- @overload fun(color: RatScratch.Graphics.GammaColor?, c: number, a?: number): RatScratch.Graphics.GammaColor
function GammaColor.fromLinear(self, r, g, b, a)
	self = self or GammaColor()
	self:from(r, g, b, a)

	self.r, self.g, self.b = love.math.linearToGamma(self.r, self.g, self.b)

	--- @cast self RatScratch.Graphics.GammaColor
	return self
end

function GammaColor:toLinear()
	local r, g, b = love.math.gammaToLinear(self.r, self.g, self.b)
	return r, g, b, self.a
end

return GammaColor
