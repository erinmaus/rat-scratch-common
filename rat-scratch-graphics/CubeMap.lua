local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local CubeMap = {}

CubeMap.FACES = 6

CubeMap.NORMALS = {
	Vector3(1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(0, 1, 0),
	Vector3(0, -1, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
}

CubeMap.TANGENTS = {
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
	Vector3(-1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
}

CubeMap.BITANGENTS = {
	Vector3(0, -1, 0),
	Vector3(0, -1, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
	Vector3(0, -1, 0),
	Vector3(0, -1, 0),
}

CubeMap.ROTATIONS = {
	Quaternion.fromAxisAngle(Vector3.UNIT_Y, -math.pi / 2),
	Quaternion.fromAxisAngle(Vector3.UNIT_Y, math.pi / 2),
	Quaternion.fromAxisAngle(Vector3.UNIT_X, math.pi / 2),
	Quaternion.fromAxisAngle(Vector3.UNIT_X, -math.pi / 2),
	Quaternion.fromAxisAngle(Vector3.UNIT_Y, math.pi),
	Quaternion.IDENTITY,
}

CubeMap.FACE_POSITIVE_X = 1
CubeMap.FACE_NEGATIVE_X = 2
CubeMap.FACE_POSITIVE_Y = 3
CubeMap.FACE_NEGATIVE_Y = 4
CubeMap.FACE_POSITIVE_Z = 5
CubeMap.FACE_NEGATIVE_Z = 6

do
	local _t = Vector3()
	local _b = Vector3()

	--- @param faceIndex integer
	--- @param result? RatScratch.Math.Quaternion
	--- @return RatScratch.Math.Quaternion
	function CubeMap.getRotation(faceIndex, result)
		-- local N = CubeMap.NORMALS[faceIndex]
		-- local T = CubeMap.TANGENTS[faceIndex]:negate(_t)
		-- local B = CubeMap.BITANGENTS[faceIndex]:negate(_b)
		-- return Quaternion.fromTBN(N, T, B, result)
		return CubeMap.ROTATIONS[faceIndex]
	end
end

do
	local _absoluteDirection = Vector3()

	--- @param direction RatScratch.Math.Vector3
	--- @return integer, number, number
	function CubeMap.getFaceTextureCoordinate(direction)
		local absoluteDirection = direction:abs(_absoluteDirection)
		local positiveAxisX = absoluteDirection.x > 0.0
		local positiveAxisY = absoluteDirection.y > 0.0
		local positiveAxisZ = absoluteDirection.z > 0.0
		local maxAxisValue = math.max(
			absoluteDirection.x,
			absoluteDirection.y,
			absoluteDirection.z
		)

		local faceIndex, s, t
		if
			absoluteDirection.x >= absoluteDirection.y
			and absoluteDirection.x >= absoluteDirection.z
		then
			if positiveAxisX then
				faceIndex = CubeMap.FACE_POSITIVE_X
				s, t = direction.z, -direction.y
			else
				faceIndex = CubeMap.FACE_NEGATIVE_X
				s, t = -direction.z, -direction.y
			end
		elseif
			absoluteDirection.y >= absoluteDirection.x
			and absoluteDirection.y >= absoluteDirection.z
		then
			if positiveAxisY then
				faceIndex = CubeMap.FACE_POSITIVE_Y
				s, t = -direction.x, direction.z
			else
				faceIndex = CubeMap.FACE_NEGATIVE_Y
				s, t = -direction.x, -direction.z
			end
		else
			if positiveAxisZ then
				faceIndex = CubeMap.FACE_POSITIVE_Z
				s, t = -direction.x, -direction.y
			else
				faceIndex = CubeMap.FACE_NEGATIVE_Z
				s, t = direction.x, -direction.y
			end
		end

		s = ((s / maxAxisValue) + 1) / 2
		t = ((t / maxAxisValue) + 1) / 2

		return faceIndex, s, t
	end
end

do
	local _t = Vector3()
	local _b = Vector3()

	function CubeMap.getCoordinateFromFaceTextureCoordinate(face, s, t, result)
		result = result or Vector3()

		s, t = s * 2 - 1, t * 2 - 1

		local N = CubeMap.NORMALS[face]
		local T = CubeMap.TANGENTS[face]:scale(s, _t)
		local B = CubeMap.BITANGENTS[face]:scale(t, _b)

		return N:add(T, result):add(B, result)
	end
end

function CubeMap.getNormalFromFaceTextureCoordinate(face, s, t, result)
	result = result or Vector3()

	return CubeMap.getCoordinateFromFaceTextureCoordinate(face, s, t, result)
		:normalize(result)
end

return CubeMap
