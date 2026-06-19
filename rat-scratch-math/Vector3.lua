local Object = require("rat-scratch-common").Object
local Common = require("rat-scratch-math.Common")

--- @class RatScratch.Math.Vector3
--- @overload fun(x?: number, y?: number, z?: number): RatScratch.Math.Vector3
--- @field public x number
--- @field public y number
--- @field public z number
local Vector3 = Object()

--- @param x number?
--- @param y number?
--- @param z number?
function Vector3:new(x, y, z)
	if not x and not y and not z then
		x = 0
		y = 0
		z = 0
	elseif x and not y and not z then
		y = x
		z = z
	elseif x and y and not z then
		z = 0
	end

	self.x = x
	self.y = y
	self.z = z
end

---@param x number?
---@param y number?
---@param z number?
---@return RatScratch.Math.Vector3
function Vector3:from(x, y, z)
	if x and y and z then
		self.x = x
		self.y = y
		self.z = z
	elseif x and y and not z then
		self.x = x
		self.y = y
		self.z = 0
	elseif x then
		self.x = x
		self.y = x
		self.z = x
	else
		self.x = 0
		self.y = 0
		self.z = 0
	end

	return self
end

--- @return number
--- @return number
--- @return number
function Vector3:get()
	return self.x, self.y, self.z
end

--- @param result RatScratch.Math.Vector3??
--- @return RatScratch.Math.Vector3
function Vector3:abs(result)
	result = result or Vector3()
	return result:from(math.abs(self.x), math.abs(self.y), math.abs(self.z))
end

--- @param result RatScratch.Math.Vector3??
--- @return RatScratch.Math.Vector3
function Vector3:floor(result)
	result = result or Vector3()
	return result:from(math.floor(self.x), math.floor(self.y), math.floor(self.z))
end

--- @param result RatScratch.Math.Vector3??
--- @return RatScratch.Math.Vector3
function Vector3:ceil(result)
	result = result or Vector3()
	return result:from(math.ceil(self.x), math.ceil(self.y), math.ceil(self.z))
end

--- @param other RatScratch.Math.Vector3
--- @return number
function Vector3:dot(other)
	return self.x * other.x + self.y * other.y + self.z * other.z
end

do
	local dot = Vector3()
	local TWO = Vector3(2)

	--- @param normal RatScratch.Math.Vector3
	--- @param result RatScratch.Math.Vector3?
	--- @return RatScratch.Math.Vector3
	function Vector3:reflect(normal, result)
		result = result or Vector3()

		dot:from(self:dot(normal))
		return self:subtract(TWO:product(normal, result):product(dot, result), result)
	end
end

do
	local v1 = Vector3()
	local v2 = Vector3()

	--- @param other RatScratch.Math.Vector3
	--- @param result RatScratch.Math.Vector3?
	--- @return RatScratch.Math.Vector3
	--- @return number
	function Vector3:project(other, result)
		result = result or Vector3()

		local d = self:dot(other)
		v2:from(other:getLengthSquared())
		v1:from(1 / d):product(v2, result):product(other, result)

		return result, d
	end
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:min(other, result)
	result = result or Vector3()
	return result:from(math.min(self.x, other.x), math.min(self.y, other.y), math.min(self.z, other.z))
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:max(other, result)
	result = result or Vector3()
	return result:from(math.max(self.x, other.x), math.max(self.y, other.y), math.max(self.z, other.z))
end

--- @param min RatScratch.Math.Vector3
--- @param max RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:clamp(min, max, result)
	result = result or Vector3()
	return self:min(max, result):max(min, result)
end

--- @param transform love.Transform
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:transform(transform, result)
	result = result or Vector3()

	if not transform then
		return result:from(self.x, self.y, self.z)
	end

	local m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44 = transform:getMatrix()

	return result:from(
		m11 * self.x + m12 * self.y + m13 * self.z,
		m21 * self.x + m22 * self.y + m23 * self.z,
		m31 * self.x + m32 * self.y + m33 * self.z
	)
end

--- @param transform love.Transform
--- @param w number?
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3, number
function Vector3:perspectiveTransform(transform, w, result)
	result = result or Vector3()
	w = w or 1

	if not transform then
		return result:from(self.x, self.y, self.z), w
	end

	local m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44 = transform:getMatrix()

	return result:from(
		m11 * self.x + m12 * self.y + m13 * self.z + m14 * w,
		m21 * self.x + m22 * self.y + m23 * self.z + m24 * w,
		m31 * self.x + m32 * self.y + m33 * self.z + m24 * w
	),
		m41 * self.x + m42 * self.y + m43 * self.z + m44 * w
end

--- @param other RatScratch.Math.Vector3
--- @param delta number
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:lerp(other, delta, result)
	delta = math.min(math.max(delta, 0.0), 1.0)

	local result = result or Vector3()
	return result:from(
		other.x * delta + self.x * (1 - delta),
		other.y * delta + self.y * (1 - delta),
		other.z * delta + self.z * (1 - delta)
	)
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:cross(other, result)
	local result = result or Vector3()
	return result:from(
		self.y * other.z - self.z * other.y,
		self.z * other.x - self.x * other.z,
		self.x * other.y - self.y * other.x
	)
end

do
	local difference = Vector3()

	--- @param other RatScratch.Math.Vector3
	--- @return number
	function Vector3:distance(other)
		return self:subtract(other, difference):getLength()
	end
end

do
	local difference = Vector3()

	--- @param other RatScratch.Math.Vector3
	--- @return number
	function Vector3:distanceSquared(other)
		return self:subtract(other, difference):getLengthSquared()
	end
end

--- @return number
function Vector3:getLengthSquared()
	return self.x * self.x + self.y * self.y + self.z * self.z
end

--- @return number
function Vector3:getLength()
	local lengthSquared = self:getLengthSquared()
	if lengthSquared == 0 then
		return 0
	else
		return math.sqrt(self:getLengthSquared())
	end
end

do
	local length = Vector3()

	--- @param result RatScratch.Math.Vector3?
	--- @return RatScratch.Math.Vector3
	function Vector3:normalize(result)
		result = result or Vector3()

		local length = length:from(self:getLength())
		if length:get() == 0 then
			result:from(0)
		else
			length:from(1 / length:get())
			self:product(length, result)
		end

		return result
	end
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:direction(other, result)
	result = result or Vector3()

	other:subtract(self, result)
	result:normalize(result)

	return result
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:add(other, result)
	result = result or Vector3()
	result.x = self.x + other.x
	result.y = self.y + other.y
	result.z = self.z + other.z
	return result
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:subtract(other, result)
	result = result or Vector3()
	result.x = self.x - other.x
	result.y = self.y - other.y
	result.z = self.z - other.z
	return result
end

--- @param scale number
--- @param result? RatScratch.Math.Vector3
--- @return RatScratch.Math.Vector3
function Vector3:scale(scale, result)
	result = result or Vector3()
	result.x = result.x * scale
	result.y = result.y * scale
	result.z = result.z * scale
	return result
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:product(other, result)
	result = result or Vector3()
	result.x = self.x * other.x
	result.y = self.y * other.y
	result.z = self.z * other.z
	return result
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:divide(other, result)
	result = result or Vector3()
	result.x = self.x / other.x
	result.y = self.y / other.y
	result.z = self.z / other.z
	return result
end

--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:negate(result)
	result = result or Vector3()
	result.x = -self.x
	result.y = -self.y
	result.z = -self.z
	return result
end

--- @param other RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Vector3:power(other, result)
	result = result or Vector3()
	result.x = self.x ^ other.x
	result.y = self.y ^ other.y
	result.z = self.z ^ other.z
	return result
end

--- @param other RatScratch.Math.Vector3
--- @param e number?
function Vector3:equal(other, e)
	e = e or Common.EPSILON

	return math.abs(self.x - other.x) < e and math.abs(self.y - other.z) < e and math.abs(self.y - other.z) < e
end

Vector3.ZERO = Vector3(0, 0, 0)
Vector3.ONE = Vector3(1, 1, 1)
Vector3.UNIT_X = Vector3(1, 0, 0)
Vector3.UNIT_Y = Vector3(0, 1, 0)
Vector3.UNIT_Z = Vector3(0, 0, 1)

return Vector3
