local Object = require("rat-scratch-common").Object
local Common = require("rat-scratch-math.Common")
local Vector3 = require("rat-scratch-math.Vector3")

--- @class RatScratch.Math.Quaternion : RatScratch.Common.BaseObject
--- @overload fun(x?: number, y?: number, z?: number, w?: number): RatScratch.Math.Quaternion
--- @field public x number
--- @field public y number
--- @field public z number
--- @field public w number
local Quaternion = Object()

--- @param x number?
--- @param y number?
--- @param z number?
--- @param w number?
function Quaternion:new(x, y, z, w)
	if not (x and y and z and w) then
		x = 0
		y = 0
		z = 0
		w = 1
	end

	self.x = x
	self.y = y
	self.z = z
	self.w = w
end

do
	local scale = Vector3()
	local axisNormal = Vector3()
	local xyz = Vector3()

	--- @param axis RatScratch.Math.Vector3
	--- @param angle number
	--- @param result RatScratch.Math.Quaternion?
	--- @return unknown
	function Quaternion.fromAxisAngle(axis, angle, result)
		local scale = scale
		local axisNormal = axisNormal
		local xyz = xyz

		local halfAngle = angle * 0.5
		local halfAngleSine = math.sin(halfAngle)
		local halfAngleCosine = math.cos(halfAngle)

		scale:from(halfAngleSine)
		axis:normalize(axisNormal)
		axisNormal:product(scale, xyz)

		local w = halfAngleCosine

		result = result or Quaternion()
		return result:from(xyz.x, xyz.y, xyz.z, w)
	end
end

do
	local F = Vector3()
	local R = Vector3()
	local U = Vector3()

	--- @param source RatScratch.Math.Vector3
	--- @param target RatScratch.Math.Vector3
	--- @param up RatScratch.Math.Vector3?
	--- @param result RatScratch.Math.Quaternion
	--- @return RatScratch.Math.Quaternion
	function Quaternion.lookAt(source, target, up, result)
		local E = Common.EPSILON

		result = result or Quaternion()
		up = up or Vector3.UNIT_Y

		-- From https://stackoverflow.com/a/52551983

		source:direction(target, F)
		up:cross(F, R):normalize(R)
		F:cross(R, U):normalize(U)

		if
			F:getLengthSquared() == 0
			or R:getLengthSquared() == 0
			or U:getLengthSquared() == 0
		then
			result:from()
			return result
		end

		local trace = R.x + U.y + F.z
		if trace > 0 then
			local s = 0.5 / math.sqrt(trace + 1)
			if math.abs(s) < E then
				result:from()
			else
				result.x = (U.z - F.y) * s
				result.y = (F.x - R.z) * s
				result.z = (R.y - U.x) * s
				result.w = 0.25 / s
			end
		end

		if R.x > U.y and R.x > F.z then
			local s = 2 * math.sqrt(1 + R.x - U.y - F.z)
			if math.abs(s) < E then
				result:from()
			else
				result.x = 0.25 * s
				result.y = (U.x + R.y) / s
				result.z = (F.x + R.z) / s
				result.w = (U.z - F.y) / s
			end
		end

		if U.y > F.z then
			local s = 2 * math.sqrt(1 + U.y - R.x - F.z)
			if math.abs(s) < E then
				result:from()
			else
				result.x = (U.x + R.y) / s
				result.y = 0.25 * s
				result.z = (F.y + U.z) / s
				result.w = (F.x - R.z) / s
			end
		else
			local s = 2 * math.sqrt(1 + F.z - R.x - U.y)
			if math.abs(s) < E then
				result:from()
			else
				result.x = (F.x + R.z) / s
				result.y = (F.y + U.z) / s
				result.z = 0.25 * s
				result.w = (R.y - U.x) / s
			end
		end

		return result
	end
end

do
	local sourceNormal = Vector3()
	local targetNormal = Vector3()
	local cross = Vector3()
	local scale = Vector3()

	--- @param source RatScratch.Math.Vector3
	--- @param target RatScratch.Math.Vector3
	--- @param result RatScratch.Math.Quaternion
	--- @return RatScratch.Math.Quaternion
	function Quaternion.fromVectors(source, target, result)
		local dot =
			source:normalize(sourceNormal):dot(target:normalize(targetNormal))
		local halfCos = math.sqrt((1 + dot) / 2)
		local halfSin = math.sqrt((1 - dot) / 2)
		cross = sourceNormal:cross(targetNormal, cross):normalize(cross)
		cross:product(scale:from(halfSin), cross)

		result = result or Quaternion()
		return result:from(cross.x, cross.y, cross.z, halfCos)
	end
end

function Quaternion:from(x, y, z, w)
	if not (x and y and z and w) then
		x = 0
		y = 0
		z = 0
		w = 1
	end

	self.x = x
	self.y = y
	self.z = z
	self.w = w

	return self
end

--- @return number
--- @return number
--- @return number
--- @return number
function Quaternion:get()
	return self.x, self.y, self.z, self.w
end

do
	local deltaQuaternion = Quaternion()
	local inverseDeltaQuaternion = Quaternion()
	local otherDeltaProduct = Quaternion()
	local selfInverseDeltaProduct = Quaternion()

	--- @param other RatScratch.Math.Quaternion
	--- @param delta number
	--- @param result RatScratch.Math.Quaternion?
	--- @return RatScratch.Math.Quaternion
	function Quaternion:lerp(other, delta, result)
		delta = math.min(math.max(delta, 0.0), 1.0)
		local inverseDelta = 1 - delta

		result = result or Quaternion()

		deltaQuaternion:from(delta, delta, delta, delta)
		inverseDeltaQuaternion:from(
			inverseDelta,
			inverseDelta,
			inverseDelta,
			inverseDelta
		)

		other:product(deltaQuaternion, otherDeltaProduct)
		self:product(inverseDeltaQuaternion, selfInverseDeltaProduct)

		return otherDeltaProduct:add(selfInverseDeltaProduct, result)
	end
end

--- @param other RatScratch.Math.Quaternion
--- @param delta number
--- @param result RatScratch.Math.Quaternion?
--- @return RatScratch.Math.Quaternion
function Quaternion:slerp(other, delta, result)
	delta = math.min(math.max(delta, 0.0), 1.0)

	-- Calculate angle between quaternions.
	local dot = self.x * other.x
		+ self.y * other.y
		+ self.z * other.z
		+ self.w * other.w

	local theta = math.acos(dot)
	local sine = math.sin(1 - theta * theta)
	local c1, c2
	if theta > 0 then
		c1 = math.sin((1.0 - delta) * theta) / sine
		c2 = math.sin(delta * theta) / sine
	else
		c1 = 1 - delta
		c2 = delta
	end

	local result = result or Quaternion()

	if dot < 0 then
		result.x = self.x * c1 - other.x * c2
		result.y = self.y * c1 - other.y * c2
		result.z = self.z * c1 - other.z * c2
		result.w = self.w * c1 - other.w * c2
	else
		result.x = self.x * c1 + other.x * c2
		result.y = self.y * c1 + other.y * c2
		result.z = self.z * c1 + other.z * c2
		result.w = self.w * c1 + other.w * c2
	end

	return result
end

--- @return number
function Quaternion:getLengthSquared()
	return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
end

--- @return number
function Quaternion:getLength()
	return math.sqrt(self:getLengthSquared())
end

do
	local q = Quaternion()
	local v = Vector3()

	--- @param other RatScratch.Math.Quaternion
	--- @return number
	function Quaternion:distance(other)
		self:conjugate(q):product(other, q)
		v:from(q.x, q.y, q.z)
		return 2 * math.atan2(v:getLength(), q.w)
	end
end

--- @param result RatScratch.Math.Quaternion?
--- @return RatScratch.Math.Quaternion
function Quaternion:normalize(result)
	result = result or Quaternion()

	local length = self:getLength()
	if length == 0 then
		return result:from(0, 0, 0, 0)
	else
		local inverseLength = 1 / length
		return result:from(
			self.x * inverseLength,
			self.y * inverseLength,
			self.z * inverseLength,
			self.w * inverseLength
		)
	end
end

--- @param result RatScratch.Math.Quaternion?
--- @return RatScratch.Math.Quaternion
function Quaternion:inverse(result)
	local lengthSquared = self:getLengthSquared()
	if lengthSquared == 0 then
		return self
	end

	result = result or Quaternion()

	local inverseLengthSquared = 1 / lengthSquared
	return result:from(
		-self.x * inverseLengthSquared,
		-self.y * inverseLengthSquared,
		-self.z * inverseLengthSquared,
		self.w * inverseLengthSquared
	)
end

do
	local normal = Quaternion()
	local v = Quaternion()
	local conjugate = Quaternion()
	local q = Quaternion()

	--- @param vector RatScratch.Math.Vector3
	--- @param result RatScratch.Math.Vector3?
	--- @return RatScratch.Math.Vector3
	function Quaternion:transformVector(vector, result)
		result = result or Vector3()

		v:from(vector.x, vector.y, vector.z, 0)
		self:normalize(normal)
		normal:conjugate(conjugate)

		normal:product(v, q):product(conjugate, q)
		return result:from(q.x, q.y, q.z)
	end
end

do
	local rx, ry, rz = Quaternion(), Quaternion(), Quaternion()

	--- @param x number
	--- @param y number
	--- @param z number
	--- @param result RatScratch.Math.Quaternion
	--- @return RatScratch.Math.Quaternion
	function Quaternion.fromEulerXYZ(x, y, z, result)
		result = result or Quaternion()

		Quaternion.fromAxisAngle(Vector3.UNIT_X, x, rx)
		Quaternion.fromAxisAngle(Vector3.UNIT_Y, y, ry)
		Quaternion.fromAxisAngle(Vector3.UNIT_Z, z, rz)

		return rz:product(ry, result):product(rx, result):normalize(result)
	end
end

--- Same as getEulerXYZ, except returns angles in degrees - for debugging, really.
--- @return number
--- @return number
--- @return number
function Quaternion:getDebugEulerXYZ()
	local x, y, z = self:getEulerXYZ()
	return math.deg(x), math.deg(y), math.deg(z)
end

--- @return number
--- @return number
--- @return number
function Quaternion:getEulerXYZ()
	local x = math.atan2(
		2.0 * (self.y * self.z + self.w * self.x),
		self.w * self.w - self.x * self.x - self.y * self.y + self.z * self.z
	)
	local y = math.asin(
		math.min(math.max(-2.0 * (self.x * self.z - self.w * self.y), -1), 1)
	)
	local z = math.atan2(
		2.0 * (self.x * self.y + self.w * self.z),
		self.w * self.w + self.x * self.x - self.y * self.y - self.z * self.z
	)

	return x, y, z
end

--- @param other RatScratch.Math.Quaternion
--- @param result RatScratch.Math.Quaternion?
--- @return RatScratch.Math.Quaternion
function Quaternion:add(other, result)
	result = result or Quaternion()
	result:from(
		self.x + other.x,
		self.y + other.y,
		self.z + other.z,
		self.w + other.w
	)

	return result
end

---@param scale number
---@param result RatScratch.Math.Quaternion
---@return RatScratch.Math.Quaternion
function Quaternion:scale(scale, result)
	result = result or Quaternion()
	return result:from(
		self.x * scale,
		self.y * scale,
		self.z * scale,
		self.w * scale
	)
end

--- @param other RatScratch.Math.Quaternion
--- @param result RatScratch.Math.Quaternion?
--- @return RatScratch.Math.Quaternion
function Quaternion:product(other, result)
	local a = self
	local b = other

	result = result or Quaternion()
	result:from(
		a.x * b.w + a.y * b.z - a.z * b.y + a.w * b.x,
		-a.x * b.z + a.y * b.w + a.z * b.x + a.w * b.y,
		a.x * b.y - a.y * b.x + a.z * b.w + a.w * b.z,
		-a.x * b.x - a.y * b.y - a.z * b.z + a.w * b.w
	)
	return result
end

--- @param result RatScratch.Math.Quaternion?
--- @return RatScratch.Math.Quaternion
function Quaternion:conjugate(result)
	result = result or Quaternion()
	return result:from(-self.x, -self.y, -self.z, self.w)
end

-- Some useful quaternion constants.
Quaternion.IDENTITY = Quaternion(0, 0, 0, 1)
Quaternion.ZERO = Quaternion(0, 0, 0, 0)

Quaternion.X_90 = Quaternion.fromAxisAngle(Vector3.UNIT_X, math.pi / 2)
Quaternion.X_180 = Quaternion.fromAxisAngle(Vector3.UNIT_X, math.pi)
Quaternion.X_270 =
	Quaternion.fromAxisAngle(Vector3.UNIT_X, math.pi + math.pi / 2)

Quaternion.Y_90 = Quaternion.fromAxisAngle(Vector3.UNIT_Y, math.pi / 2)
Quaternion.Y_180 = Quaternion.fromAxisAngle(Vector3.UNIT_Y, math.pi)
Quaternion.Y_270 =
	Quaternion.fromAxisAngle(Vector3.UNIT_Y, math.pi + math.pi / 2)

Quaternion.Z_90 = Quaternion.fromAxisAngle(Vector3.UNIT_Z, math.pi / 2)
Quaternion.Z_180 = Quaternion.fromAxisAngle(Vector3.UNIT_Z, math.pi)
Quaternion.Z_270 =
	Quaternion.fromAxisAngle(Vector3.UNIT_Z, math.pi + math.pi / 2)

return Quaternion
