local Object = require("rat-scratch-common").Object
local Common = require("rat-scratch-math").Common

--- @class RatScratch.Graphics.LinearColor : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Graphics.LinearColor
--- @overload fun(c: number): RatScratch.Graphics.LinearColor
--- @overload fun(r: number, g: number, b: number): RatScratch.Graphics.LinearColor
--- @overload fun(r: number, g: number, b: number, a: number): RatScratch.Graphics.LinearColor
--- @overload fun(c: number, a: number): RatScratch.Graphics.LinearColor
local LinearColor = Object()

function LinearColor:new(r, g, b, a)
	self:from(r, g, b, a)
end

--- @return number, number, number, number
function LinearColor:get()
	return self.r, self.g, self.b, self.a
end

--- @overload fun(self: RatScratch.Graphics.LinearColor): RatScratch.Graphics.LinearColor
--- @overload fun(self: RatScratch.Graphics.LinearColor, c: number): RatScratch.Graphics.LinearColor
--- @overload fun(self: RatScratch.Graphics.LinearColor, r: number, g: number, b: number): RatScratch.Graphics.LinearColor
--- @overload fun(self: RatScratch.Graphics.LinearColor, r: number, g: number, b: number, a: number): RatScratch.Graphics.LinearColor
--- @overload fun(self: RatScratch.Graphics.LinearColor, c: number, a: number): RatScratch.Graphics.LinearColor
--- @return RatScratch.Graphics.LinearColor
function LinearColor:from(c1, c2, c3, c4)
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

--- @param other RatScratch.Graphics.LinearColor
--- @param delta number
--- @param result? RatScratch.Graphics.LinearColor
function LinearColor:lerp(other, delta, result)
	result = result or LinearColor()
	return result:from(
		Common.lerp(self.r, other.r, delta),
		Common.lerp(self.g, other.g, delta),
		Common.lerp(self.b, other.b, delta),
		Common.lerp(self.a, other.a, delta)
	)
end

--- @param other RatScratch.Graphics.LinearColor
--- @param result? RatScratch.Graphics.LinearColor
function LinearColor:blend(other, result)
	result = result or LinearColor()
	return result:from(
		self.r * other.r,
		self.g * other.g,
		self.b * other.b,
		self.a * other.a
	)
end

--- @param destination RatScratch.Graphics.LinearColor
--- @param source RatScratch.Graphics.LinearColor
--- @return RatScratch.Graphics.LinearColor
function LinearColor.blendAlpha(destination, source, result)
	result = result or LinearColor()

	return result
		:from(
			destination.r * (1 - source.a) + source.a * source.r,
			destination.b * (1 - source.a) + source.a * source.b,
			destination.g * (1 - source.a) + source.a * source.g,
			destination.a * (1 - source.a) + source.a
		)
		:saturate(result)
end

--- @param destination RatScratch.Graphics.LinearColor
--- @param source RatScratch.Graphics.LinearColor
--- @return RatScratch.Graphics.LinearColor
function LinearColor.blendAdditive(destination, source, result)
	result = result or LinearColor()

	return result
		:from(
			destination.r + source.a * source.r,
			destination.b + source.a * source.b,
			destination.g + source.a * source.g,
			destination.a + source.a
		)
		:saturate(result)
end

--- @param result? RatScratch.Graphics.LinearColor
--- @return RatScratch.Graphics.LinearColor
function LinearColor:saturate(result)
	result = result or LinearColor()
	return result:from(
		Common.saturate(self.r),
		Common.saturate(self.g),
		Common.saturate(self.b),
		Common.saturate(self.a)
	)
end

--- @overload fun(color: RatScratch.Graphics.LinearColor?): RatScratch.Graphics.LinearColor
--- @overload fun(color: RatScratch.Graphics.LinearColor?, c: number): RatScratch.Graphics.LinearColor
--- @overload fun(color: RatScratch.Graphics.LinearColor?, r: number, g: number, b: number): RatScratch.Graphics.LinearColor
--- @overload fun(color: RatScratch.Graphics.LinearColor?, r: number, g: number, b: number, a: number): RatScratch.Graphics.LinearColor
--- @overload fun(color: RatScratch.Graphics.LinearColor?, c: number, a?: number): RatScratch.Graphics.LinearColor
function LinearColor.fromGammaCorrect(self, r, g, b, a)
	self = self or LinearColor()
	self:from(r, g, b, a)

	self.r, self.g, self.b = love.math.gammaToLinear(self.r, self.g, self.b)

	--- @cast self RatScratch.Graphics.LinearColor
	return self
end

function LinearColor:toGammaCorrect()
	local r, g, b = love.math.linearToGamma(self.r, self.g, self.b)
	return r, g, b, self.a
end

return LinearColor
