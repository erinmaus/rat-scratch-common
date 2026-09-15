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
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
	Vector3(1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(-1, 0, 0),
}

CubeMap.BITANGENTS = {
	Vector3(0, 1, 0),
	Vector3(0, 1, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
	Vector3(0, 1, 0),
	Vector3(0, 1, 0),
}

--- @param faceIndex integer
--- @param result? RatScratch.Math.Quaternion
--- @return RatScratch.Math.Quaternion
function CubeMap.getRotation(faceIndex, result)
	return Quaternion.fromTBN(
		CubeMap.NORMALS[faceIndex],
		CubeMap.TANGENTS[faceIndex],
		CubeMap.BITANGENTS[faceIndex],
		result
	)
end

return CubeMap
