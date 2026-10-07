local Table = require("rat-scratch-common").Table
local Gaussian = {}

--- @param radius integer
--- @param sigma number
--- @param result? number[]
--- @return number[]
function Gaussian.generateSeparableKernel(radius, sigma, result)
	local size = radius * 2 + 1

	result = result or Table.new(size, 0)
	Table.clear(result)

	local sum = 0
	for i = 1, size do
		local x = (i - 1) - radius
		local value = math.exp(-(x * x) / (2 * sigma * sigma))
		result[i] = value

		sum = sum + value
	end

	local inverseSum = 1 / sum
	for i = 1, #result do
		result[i] = result[i] * inverseSum
	end

	return result
end

return Gaussian
