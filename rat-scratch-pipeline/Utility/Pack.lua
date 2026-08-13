local bit = require("bit")
local Vector3 = require("rat-scratch-math").Vector3
local Common = require("rat-scratch-math").Common

local Pack = {}

--- @param x number
--- @param y number
--- @param z number
--- @param w number
--- @return integer
function Pack.packUnorm4x8(x, y, z, w)
	x = Common.round(Common.clamp(x, 0, 1) * 255)
	y = Common.round(Common.clamp(y, 0, 1) * 255)
	z = Common.round(Common.clamp(z, 0, 1) * 255)
	w = Common.round(Common.clamp(w, 0, 1) * 255)

	local result =
		bit.bor(x, bit.lshift(y, 8), bit.lshift(z, 16), bit.lshift(w, 24))
	if result < 0 then
		result = 0xFFFFFFFF - (math.abs(result) - 1)
	end

	return result
end

--- @param value integer
--- @return number, number, number, number
function Pack.unpackUnorm4x8(value)
	local x = bit.band(value, 0xFF) / 255
	local y = bit.band(bit.rshift(value, 8), 0xFF) / 255
	local z = bit.band(bit.rshift(value, 16), 0xFF) / 255
	local w = bit.band(bit.rshift(value, 24), 0xFF) / 255

	return x, y, z, w
end

do
	local ONE = Vector3(1)
	local TWO = Vector3(2)
	local normal = Vector3()
	local result = Vector3()
	local EPSILON = Vector3(Common.EPSILON)
	local step = Vector3()

	--- @param x number
	--- @param y number
	--- @param z number
	--- @return number, number, number
	function Pack.clampNormal(x, y, z)
		local n = normal:from(x, y, z)
		local r = result

		n:add(ONE, r):divide(TWO, r)
		r:product(r:step(EPSILON, step), r)

		r:product(TWO, r):subtract(ONE, r)
		r:normalize(r)

		return r:get()
	end
end

do
	local normalXY = Vector3()
	local lPlusD = Vector3()
	local square = Vector3()
	local result = Vector3()

	--- @param x number
	--- @param y number
	--- @param z number
	--- @return number, number
	function Pack.encodeNormal(x, y, z)
		local xy = normalXY:from(x, y, 0)
		local l = xy:getLength()
		local d = Common.step(l, 0.0)
		local s = l + d
		local sq = math.sqrt(Common.clamp((-z + 1.0) / 2.0, 0, 1))
		local r = xy:divide(lPlusD:from(s, s, 0), result)
			:product(square:from(sq, sq, 0), result)
		local nx, ny = r:get()
		return nx, ny
	end
end

do
	local normal = Vector3()
	local encodedNormal1 = Vector3()
	local encodedNormal2 = Vector3()
	local TWO = Vector3(2)
	local ZERO_ZERO_ONE = Vector3(0, 0, 1)
	local scale = Vector3()
	local result = Vector3()

	--- @param nx number
	--- @param ny number
	--- @return number, number, number
	function Pack.decodeNormal(nx, ny)
		local n = normal:from(nx, ny)
		local e1 = encodedNormal1:from(nx, ny, 1)
		local e2 = encodedNormal2:from(-nx, -ny, 1)
		local l = e1:dot(e2)
		local s = n:scale(math.sqrt(l), scale)
		local r = result
			:from(s.x, s.y, l)
			:product(TWO, result)
			:subtract(ZERO_ZERO_ONE)
		return r:get()
	end
end

--- @param x number
--- @param y number
--- @param z number
--- @return number, number
function Pack.packNormal2(x, y, z)
	return Pack.encodeNormal(Pack.clampNormal(x, y, z))
end

--- @param x number
--- @param y number
--- @return number, number, number
function Pack.unpackNormal2(x, y)
	return Pack.decodeNormal(x, y)
end

--- @param x number
--- @param y number
--- @param z number
--- @param w number
--- @return number, number, number
function Pack.packTangent3(x, y, z, w)
	local x, y = Pack.encodeNormal(Pack.clampNormal(x, y, z))
	return x, y, w
end

--- @param x number
--- @param y number
--- @param z number
--- @return number, number, number, number
function Pack.unpackTangent3(x, y, z)
	local tx, ty, tz = Pack.decodeNormal(x, y)
	return tx, ty, tz, z
end

--- @param x integer
--- @param y integer
--- @param z integer
--- @param w integer
--- @return integer, integer
function Pack.packBoneIndices2(x, y, z, w)
	local bx = bit.bor(bit.band(x, 0xFFFF), bit.lshift(bit.band(y, 0xFFFF), 16))
	local by = bit.bor(bit.band(z, 0xFFFF), bit.lshift(bit.band(w, 0xFFFF), 16))

	return bx, by
end

--- @param x integer
--- @param y integer
--- @return integer, integer, integer, integer
function Pack.unpackBoneIndices2(x, y)
	local bx = bit.band(x, 0xFFFF)
	local by = bit.band(bit.lshift(x, 16), 16)
	local bz = bit.band(y, 0xFFFF)
	local bw = bit.band(bit.lshift(y, 16), 16)

	return bx, by, bz, bw
end

return Pack
