local GammaColor = require("rat-scratch-graphics.GammaColor")
local LinearColor = require("rat-scratch-graphics.LinearColor")

--- @alias RatScratch.Graphics.Color RatScratch.Graphics.GammaColor | RatScratch.Graphics.LinearColor

local Color = {}

--- @param color RatScratch.Graphics.Color
--- @param result RatScratch.Graphics.LinearColor
--- @return RatScratch.Graphics.LinearColor
function Color.asLinear(color, result)
	result = result or LinearColor()

	if color:isDerived(GammaColor) then
		--- @cast color RatScratch.Graphics.GammaColor
		result:from(color:toLinear())
	else
		result:from(color:get())
	end

	return result
end

--- @param color RatScratch.Graphics.Color
--- @param result RatScratch.Graphics.GammaColor
--- @return RatScratch.Graphics.GammaColor
function Color.asGamma(color, result)
	result = result or GammaColor()

	if color:isDerived(LinearColor) then
		--- @cast color RatScratch.Graphics.LinearColor
		result:from(color:toGammaCorrect())
	else
		result:from(color:get())
	end

	return result
end

--- @generic F, T
--- @param from F
--- @param to T
--- @return T
function Color.convert(from, to)
	--- @cast from RatScratch.Graphics.Color
	--- @cast to RatScratch.Graphics.Color

	if from:isDerived(LinearColor) and to:isDerived(GammaColor) then
		--- @cast from RatScratch.Graphics.LinearColor
		return to:from(from:toGammaCorrect())
	elseif from:isDerived(GammaColor) and to:isDerived(LinearColor) then
		--- @cast to RatScratch.Graphics.GammaColor
		return to:from(from:toLinear())
	end

	return to
end

do
	local _linearDestination, _linearSource = LinearColor(), LinearColor()
	local _result = LinearColor()

	--- @param from RatScratch.Graphics.Color
	--- @param to RatScratch.Graphics.Color
	--- @param delta number
	--- @param result RatScratch.Graphics.Color
	--- @return RatScratch.Graphics.Color
	function Color.lerp(from, to, delta, result)
		local d = Color.convert(from, _linearDestination)
		local s = Color.convert(to, _linearSource)
		local r = d:lerp(s, delta, _result)

		result = result or LinearColor()
		return Color.convert(r, result)
	end

	--- @param from RatScratch.Graphics.Color
	--- @param to RatScratch.Graphics.Color
	--- @param result RatScratch.Graphics.Color
	--- @return RatScratch.Graphics.Color
	function Color.blend(from, to, result)
		local d = Color.convert(from, _linearDestination)
		local s = Color.convert(to, _linearSource)
		local r = d:blend(s, _result)

		result = result or LinearColor()
		return Color.convert(r, result)
	end

	--- @param from RatScratch.Graphics.Color
	--- @param to RatScratch.Graphics.Color
	--- @param result RatScratch.Graphics.Color
	--- @return RatScratch.Graphics.Color
	function Color.blendAlpha(from, to, result)
		local d = Color.convert(from, _linearDestination)
		local s = Color.convert(to, _linearSource)
		local r = d:blendAlpha(s, _result)

		result = result or LinearColor()
		return Color.convert(r, result)
	end

	--- @param from RatScratch.Graphics.Color
	--- @param to RatScratch.Graphics.Color
	--- @param result RatScratch.Graphics.Color
	--- @return RatScratch.Graphics.Color
	function Color.blendAdditive(from, to, result)
		local d = Color.convert(from, _linearDestination)
		local s = Color.convert(to, _linearSource)
		local r = d:blendAdditive(s, _result)

		result = result or LinearColor()
		return Color.convert(r, result)
	end
end

return Color
