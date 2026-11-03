local Common = require "rat-scratch-math.Common"
local Vector3 = require "rat-scratch-math.Vector3"

local Triangle = {}

do
	local _edge1, _edge2 = Vector3(), Vector3()
	local _h, _s, _q = Vector3(), Vector3(), Vector3()

	--- @param v1 RatScratch.Math.Vector3
	--- @param v2 RatScratch.Math.Vector3
	--- @param v3 RatScratch.Math.Vector3
	--- @param origin RatScratch.Math.Vector3
	--- @param direction RatScratch.Math.Vector3
	--- @param E number?
	--- @return boolean, number
	function Triangle.raycast(v1, v2, v3, origin, direction, E)
		-- http://www.lighthouse3d.com/tutorials/maths/ray-triangle-intersection/
		local edge1 = v2:subtract(v1, _edge1)
		local edge2 = v3:subtract(v1, _edge2)

		local h = direction:cross(edge2, _h)
		local a = edge1:dot(h)

		if Common.equal(a, 0, E) then
			return false, math.huge
		end

		local inverseA = 1 / a
		local s = origin:subtract(v1, _s)
		local u = inverseA * s:dot(h)

		if Common.lessThan(u, 0, E) or Common.greaterThan(u, 1, E) then
			return false, math.huge
		end

		local q = s:cross(edge1, _q)
		local v = inverseA * direction:dot(q)

		if Common.lessThan(v, 0, E) or Common.greaterThan(u + v, 1, E) then
			return false, math.huge
		end

		local t = inverseA * edge2:dot(q)
		if Common.greaterThan(t, 0, E) then
			return true, t
		end

		return false, t
	end
end

return Triangle
