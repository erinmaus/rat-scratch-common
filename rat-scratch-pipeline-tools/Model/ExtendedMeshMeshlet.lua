local ffi = require("ffi")
local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local Vector3 = require("rat-scratch-math").Vector3
local Search = require("rat-scratch-common").Search
local Common = require("rat-scratch-math").Common
local BoneInstance = require("rat-scratch-graphics").Graphics3D.BoneInstance
local Quaternion = require("rat-scratch-math").Quaternion
local Table = require("rat-scratch-common").Table

--- @class RatScratch.Pipeline.SerializedExtendedMeshMeshlet
--- @field public indexData love.ByteData
--- @field public vertexIndices integer[]
--- @field public vertices number[][]
--- @field public vertexBones table<integer, { index: number[], weight: number[] }>
--- @field public boneIndices integer[]
--- @field public primaryBone integer
--- @field public staticBoundsPosition number[]
--- @field public staticBoundsRadius number
local SerializedExtendedMeshMeshlet = {}

--- @class RatScratch.Pipeline.ExtendedMeshMeshlet : RatScratch.Common.BaseObject
--- @overload fun(indexData: love.ByteData): RatScratch.Pipeline.ExtendedMeshMeshlet
--- @field private indexData love.ByteData
--- @field private vertexIndices integer[]
--- @field private vertices RatScratch.Math.Vector3[]
--- @field private vertexBones table<integer, { index: number[], weight: number[] }>
--- @field private boneIndices integer[]
--- @field private primaryBone integer
--- @field private staticBoundsPosition RatScratch.Math.Vector3
--- @field private staticBoundsRadius number
local ExtendedMeshMeshlet = Object()

--- @param indexData love.ByteData
function ExtendedMeshMeshlet:new(indexData)
	self.indexData = indexData
	self.vertexIndices = {}
	self.vertices = {}
	self.vertexBones = {}
	self.boneIndices = {}
	self.primaryBone = 0
	self.staticBoundsPosition = Vector3()
	self.staticBoundsRadius = 0
end

--- @return RatScratch.Pipeline.SerializedExtendedMeshMeshlet
function ExtendedMeshMeshlet:serialize()
	local vertices = {}
	for _, vertex in ipairs(self.vertices) do
		table.insert(vertices, { vertex:get() })
	end

	return {
		indexData = self.indexData,
		vertexIndices = self.vertexIndices,
		vertices = vertices,
		vertexBones = self.vertexBones,
		boneIndices = self.boneIndices,
		primaryBone = self.primaryBone,
		staticBoundsPosition = { self.staticBoundsPosition:get() },
		staticBoundsRadius = self.staticBoundsRadius,
	}
end

function ExtendedMeshMeshlet:getStaticBounds()
	return self.staticBoundsPosition, self.staticBoundsRadius
end

--- @param position RatScratch.Math.Vector3
--- @param radius number
function ExtendedMeshMeshlet:setStaticBounds(position, radius)
	self.staticBoundsPosition:from(position:get())
	self.staticBoundsRadius = radius
end

function ExtendedMeshMeshlet:getIndexData()
	return self.indexData
end

function ExtendedMeshMeshlet:getUniqueVertexCount()
	return #self.vertexIndices
end

function ExtendedMeshMeshlet:getUniqueVertex(index)
	return self.vertexIndices[index]
end

function ExtendedMeshMeshlet:getUniqueBoneCount()
	return #self.boneIndices
end

function ExtendedMeshMeshlet:getUniqueBone(index)
	return self.boneIndices[index]
end

--- @return integer
function ExtendedMeshMeshlet:getPrimaryBone()
	return self.primaryBone or self.boneIndices[#self.boneIndices] or 0
end

function ExtendedMeshMeshlet:getIsSkinned()
	return #self.boneIndices > 0
end

--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @param indexData love.ByteData
--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
function ExtendedMeshMeshlet.fromMesh(pipelineConfig, indexData, meshDefinition)
	local indexFormat = BufferFormat.get(Mesh.INDEX_FORMAT)
	local meshFormat = BufferFormat.get(meshDefinition.format)

	local indexDataPointer = ffi.cast("uint32_t *", indexData:getFFIPointer())
	local indexCount = indexData:getSize() / indexFormat:getStride()

	local bones, vertexBones
	if
		meshFormat:hasAttribute("VertexBoneIndex")
		and meshFormat:hasAttribute("VertexBoneWeight")
	then
		vertexBones = {}

		local bonesByIndex = {}
		local boneWeights = {}

		local boneIndexCount, boneIndexOffset =
			meshFormat:getCountOffset("VertexBoneIndex")
		local boneWeightCount, boneWeightOffset =
			meshFormat:getCountOffset("VertexBoneWeight")
		local count = math.min(boneIndexCount, boneWeightCount)

		for i = 1, indexCount do
			local index = indexDataPointer[i - 1]
			local vertex = meshDefinition.vertices[index + 1]

			for i = 1, count do
				local boneI = boneIndexOffset + i - 1
				local weightI = boneWeightOffset + i - 1

				local bone = vertex[boneI]
				local weight = vertex[weightI]

				if weight > 0 then
					bonesByIndex[bone] = true
					boneWeights[bone] = (boneWeights[bone] or 0) + weight
				end
			end

			if not vertexBones[index] then
				vertexBones[index] = {
					index = {
						Table.unpack(
							vertex,
							boneIndexOffset,
							boneIndexOffset + boneIndexCount - 1
						),
					},
					weight = {
						Table.unpack(
							vertex,
							boneWeightOffset,
							boneWeightOffset + boneWeightCount - 1
						),
					},
				}
			end
		end

		bones = {}
		for bone in pairs(bonesByIndex) do
			table.insert(bones, bone)
		end
		table.sort(bones, function(a, b)
			return boneWeights[a] < boneWeights[b]
		end)
	end

	local verticesByIndex = {}
	for i = 1, indexCount do
		local index = indexDataPointer[i - 1]
		verticesByIndex[index] = true
	end

	local vertexIndices = {}
	for index in pairs(verticesByIndex) do
		table.insert(vertexIndices, index)
	end
	table.sort(vertexIndices)

	local vertices = {}
	do
		local _, vertexPositionOffset =
			meshFormat:getCountOffset("VertexPosition")
		local vi, vj = vertexPositionOffset, vertexPositionOffset + 2

		for _, index in ipairs(vertexIndices) do
			local inputVertex = meshDefinition.vertices[index + 1]
			local vertexPosition = Vector3(Table.unpack(inputVertex, vi, vj))
			table.insert(vertices, vertexPosition)
		end
	end

	local meshletIndexData
	do
		local triangleCount =
			pipelineConfig:getMeshletFormat():getTriangleCount()
		local targetIndexCount = triangleCount * 3
		if indexCount < targetIndexCount then
			meshletIndexData = love.data.newByteData(
				targetIndexCount * indexFormat:getStride()
			)
			ffi.copy(
				meshletIndexData:getFFIPointer(),
				indexData:getFFIPointer(),
				indexData:getSize()
			)

			local pointer =
				ffi.cast("uint32_t *", meshletIndexData:getFFIPointer())
			for i = indexCount + 1, targetIndexCount do
				pointer[i - 1] = indexDataPointer[indexCount - 1]
			end
		else
			assert(
				indexCount == targetIndexCount,
				"expected %d indices, got %d",
				targetIndexCount,
				indexCount
			)
			meshletIndexData = indexData
		end
	end

	local mesh = ExtendedMeshMeshlet(meshletIndexData)
	mesh.boneIndices = bones or mesh.boneIndices
	mesh.vertexIndices = vertexIndices
	mesh.vertices = vertices
	mesh.vertexBones = vertexBones
	mesh.primaryBone = mesh.boneIndices[#mesh.boneIndices]

	return mesh
end

--- @param serializedExtendedMeshMeshlet RatScratch.Pipeline.SerializedExtendedMeshMeshlet
--- @return RatScratch.Pipeline.ExtendedMeshMeshlet
function ExtendedMeshMeshlet.fromSerialized(serializedExtendedMeshMeshlet)
	local result = ExtendedMeshMeshlet(serializedExtendedMeshMeshlet.indexData)

	--- @type RatScratch.Math.Vector3[]
	local vertices = {}
	for _, vertex in ipairs(serializedExtendedMeshMeshlet.vertices) do
		table.insert(vertices, Vector3(unpack(vertex)))
	end

	result.boneIndices = serializedExtendedMeshMeshlet.boneIndices
	result.vertexIndices = serializedExtendedMeshMeshlet.vertexIndices
	result.vertices = vertices
	result.vertexBones = serializedExtendedMeshMeshlet.vertexBones
	result.primaryBone = serializedExtendedMeshMeshlet.primaryBone
	result.staticBoundsPosition =
		Vector3(unpack(serializedExtendedMeshMeshlet.staticBoundsPosition))
	result.staticBoundsRadius = serializedExtendedMeshMeshlet.staticBoundsRadius

	return result
end

ExtendedMeshMeshlet.PROPERTIES = {
	"position",
	"rotation",
	"scale",
}

--- @param a number
--- @param b number
local function _compareTime(a, b)
	return a - b
end

--- @param axis RatScratch.Math.Vector3
--- @param vertex RatScratch.Math.Vector3
local function _getAxisExtentAngles(axis, vertex)
	local v = axis:cross(vertex)
		:divide(axis:scale(axis:dot(vertex)):subtract(vertex))
	return v:from(-math.atan(v.x), -math.atan(v.y), -math.atan(v.z))
end

--- @param rotation RatScratch.Math.Quaternion
--- @param vertex RatScratch.Math.Vector3
local function _getRotationMinMax(rotation, vertex)
	local axis, angle = rotation:normalize():toAxisAngle()
	local extentAngles = _getAxisExtentAngles(axis, vertex)

	local minAngle = math.min(angle, 0)
	local maxAngle = math.max(0, angle)

	local angles = {
		Common.clamp(extentAngles.x, minAngle, maxAngle),
		Common.clamp(extentAngles.x - math.pi, minAngle, maxAngle),
		Common.clamp(extentAngles.x + math.pi, minAngle, maxAngle),
		Common.clamp(extentAngles.y, minAngle, maxAngle),
		Common.clamp(extentAngles.y - math.pi, minAngle, maxAngle),
		Common.clamp(extentAngles.y + math.pi, minAngle, maxAngle),
		Common.clamp(extentAngles.z, minAngle, maxAngle),
		Common.clamp(extentAngles.z - math.pi, minAngle, maxAngle),
		Common.clamp(extentAngles.z + math.pi, minAngle, maxAngle),
	}

	local rotation = Quaternion()
	local transformedVertex = Vector3()

	local min, max = Vector3(math.huge), Vector3(-math.huge)
	for _, extentAngle in ipairs(angles) do
		Quaternion.fromAxisAngle(axis, extentAngle, rotation)

		rotation:transformVector(vertex, transformedVertex)

		min:min(transformedVertex, min)
		max:max(transformedVertex, max)
	end

	return min, max
end

--- @param min RatScratch.Math.Vector3
--- @param max RatScratch.Math.Vector3
local function _getCorners(min, max)
	return {
		Vector3(min.x, min.y, min.z),
		Vector3(max.x, min.y, min.z),
		Vector3(min.x, max.y, min.z),
		Vector3(min.x, min.y, max.z),
		Vector3(max.x, max.y, min.z),
		Vector3(max.x, min.y, max.z),
		Vector3(min.x, max.y, max.z),
		Vector3(max.x, max.y, max.z),
	}
end

--- @param min RatScratch.Math.Vector3
--- @param max RatScratch.Math.Vector3
--- @param transform love.Transform
local function _transformAABB(min, max, transform)
	local corners = _getCorners(min, max)

	local min, max = Vector3(math.huge), Vector3(-math.huge)
	for _, corner in ipairs(corners) do
		min:min(corner:transform(transform), min)
		max:max(corner:transform(transform), max)
	end

	return min, max
end

--- @param min RatScratch.Math.Vector3
--- @param max RatScratch.Math.Vector3
--- @param rotation RatScratch.Math.Quaternion
local function _rotateAABB(min, max, rotation)
	local corners = _getCorners(min, max)

	local min, max = Vector3(math.huge), Vector3(-math.huge)
	for _, corner in ipairs(corners) do
		local cornerMin, cornerMax = _getRotationMinMax(rotation, corner)
		min:min(cornerMin, min)
		max:max(cornerMax, max)
	end

	return min, max
end

--- @param min RatScratch.Math.Vector3
--- @param max RatScratch.Math.Vector3
--- @param direction? "up" | "down"
--- @param t1BoneInstance RatScratch.Graphics.Graphics3D.BoneInstance
--- @param t2BoneInstance RatScratch.Graphics.Graphics3D.BoneInstance
local function _extendAABB(min, max, direction, t1BoneInstance, t2BoneInstance)
	local deltaRotation = t2BoneInstance:getRotation():product(
		t1BoneInstance:getRotation():normalize():conjugate()
	)

	local deltaTranslation = t2BoneInstance
		:getTranslation()
		:subtract(t1BoneInstance:getTranslation())

	local deltaScale
	if t2BoneInstance:getScale():getLength() < Common.EPSILON then
		deltaScale = Vector3(0)
	else
		deltaScale = t2BoneInstance:getScale():divide(t1BoneInstance:getScale())
	end

	if direction then
		local localToParent = t1BoneInstance:composeTransform()
		if direction == "down" then
			localToParent = localToParent:inverse()
		end

		min, max = _transformAABB(min, max, localToParent)
	end

	min:min(min:product(deltaScale):add(deltaTranslation), min)
	max:max(max:product(deltaScale):add(deltaTranslation), max)
	min, max = _rotateAABB(min, max, deltaRotation)

	return min, max
end

--- @param currentBone RatScratch.Graphics.Graphics3D.Bone
--- @param primaryBone RatScratch.Graphics.Graphics3D.Bone
--- @return RatScratch.Graphics.Graphics3D.Bone[], ("up" | "down")[]
local function _getBonePath(currentBone, primaryBone)
	if currentBone == primaryBone then
		return { currentBone }, { "up" }
	end

	local currentBoneAncestors = {}
	do
		--- @type RatScratch.Graphics.Graphics3D.Bone?
		local c = currentBone
		while c do
			currentBoneAncestors[c] = true
			c = c:getParent()
		end
	end

	local lowestCommonAncestor
	do
		--- @type RatScratch.Graphics.Graphics3D.Bone?
		local c = primaryBone
		while c do
			if currentBoneAncestors[c] then
				lowestCommonAncestor = c
				break
			end

			c = c:getParent()
		end
	end

	if not lowestCommonAncestor then
		return {}, {}
	end

	local path = {}
	local direction = {}
	do
		do
			--- @type RatScratch.Graphics.Graphics3D.Bone?
			local c = currentBone

			while c and c ~= lowestCommonAncestor do
				table.insert(direction, "up")
				table.insert(path, c)
				c = c:getParent()
			end

			table.insert(path, lowestCommonAncestor)
		end

		do
			local i = #path + 1

			--- @type RatScratch.Graphics.Graphics3D.Bone?
			local c = primaryBone
			while c and c ~= lowestCommonAncestor do
				table.insert(direction, "down")
				table.insert(path, i, c)
				c = c:getParent()
			end
		end
	end

	return path, direction
end

--- @private
--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @param animation RatScratch.Graphics.Graphics3D.Animation
--- @return number[]
function ExtendedMeshMeshlet:_getTimestamps(skeleton, animation)
	--- @type number[]
	local timestamps = {}

	for _, boneIndex in ipairs(self.boneIndices) do
		local bone = skeleton:getBone(boneIndex + 1)

		--- @type RatScratch.Graphics.Graphics3D.Bone?
		local current = bone
		while current do
			local channel = animation:hasBone(current)
				and animation:getChannel(current)
			if channel then
				for _, propertyName in ipairs(ExtendedMeshMeshlet.PROPERTIES) do
					local keyedProperty = channel:hasKeyedProperty(propertyName)
						and channel:getKeyedProperty(propertyName)

					if keyedProperty then
						for j = 1, keyedProperty:getFrameCount() do
							local frame = keyedProperty:getFrame(j)
							table.insert(timestamps, frame.time)
						end
					end
				end
			end

			current = current:getParent()
		end
	end

	table.sort(timestamps)
	return timestamps
end

--- @private
--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
function ExtendedMeshMeshlet:_calculateInitialSkinnedBounds(skeleton)
	local bone = skeleton:getBone(self.primaryBone + 1)

	local min, max = Vector3(math.huge), Vector3(-math.huge)
	for _, vertex in ipairs(self.vertices) do
		local localVertex = vertex:transform(bone:getInverseBindPoseTransform())
		min:min(localVertex, min)
		max:max(localVertex, max)
	end

	local center = max:subtract(min):scale(0.5):add(min)
	local radius = 0
	for _, vertex in ipairs(self.vertices) do
		local localVertex = vertex:transform(bone:getInverseBindPoseTransform())
		local distance = localVertex:distance(center)

		radius = math.max(radius, distance)
	end

	return center, radius
end

--- @private
--- @param bounds RatScratch.Math.Vector3[][]
--- @param center RatScratch.Math.Vector3
--- @param radius number
function ExtendedMeshMeshlet:_recalculateSkinnedBounds(bounds, center, radius)
	local min, max = Vector3(math.huge), Vector3(-math.huge)
	for _, vertexBounds in ipairs(bounds) do
		local vertexMin, vertexMax = vertexBounds[1], vertexBounds[2]
		min:min(vertexMin, min)
		max:max(vertexMax, max)
	end

	local corners = _getCorners(min, max)

	for _, corner in ipairs(corners) do
		local distance = corner:distance(center)
		radius = math.max(radius, distance)
	end

	return radius
end

--- @private
--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @param animation RatScratch.Graphics.Graphics3D.Animation
--- @param t1? number
--- @param t2? number
--- @return RatScratch.Math.Vector3[][]?
function ExtendedMeshMeshlet:_computeVerticesBounds(skeleton, animation, t1, t2)
	if not (t1 and t2) then
		return nil
	end

	local vertexBounds = {}

	local primaryBone = skeleton:getBone(self.primaryBone + 1)
	for i, vertexIndex in ipairs(self.vertexIndices) do
		local vertex = self.vertices[i]
		local vertexBone = self.vertexBones[vertexIndex]

		local vertexMin, vertexMax = Vector3(), Vector3()
		for j, boneIndex in ipairs(vertexBone.index) do
			local bone = skeleton:getBone(boneIndex + 1)
			local boneWeight = vertexBone.weight[j]

			local path, directions = _getBonePath(bone, primaryBone)
			if #path >= 1 then
				local boneMin, boneMax
				do
					local localVertex =
						vertex:transform(path[1]:getInverseBindPoseTransform())

					local t1BoneInstance = BoneInstance(path[1])
					local t2BoneInstance = BoneInstance(path[1])

					local channel = animation:hasBone(path[1])
						and animation:getChannel(path[1])
					if channel then
						channel:computePropertiesAtTime(t1BoneInstance, t1)
						channel:computePropertiesAtTime(t2BoneInstance, t2)

						localVertex:transform(
							t1BoneInstance:composeTransform(),
							localVertex
						)
						boneMin, boneMax = _extendAABB(
							localVertex,
							localVertex,
							nil,
							t1BoneInstance,
							t2BoneInstance
						)
					else
						boneMin, boneMax =
							Vector3(localVertex:get()),
							Vector3(localVertex:get())
					end
				end

				for k = 2, #path do
					local channel = animation:hasBone(path[k])
						and animation:getChannel(path[k])
					local t1BoneInstance = BoneInstance(path[k])
					local t2BoneInstance = BoneInstance(path[k])

					if channel then
						channel:computePropertiesAtTime(t1BoneInstance, t1)
						channel:computePropertiesAtTime(t2BoneInstance, t2)
					else
						t1BoneInstance:reset()
						t2BoneInstance:reset()
					end

					boneMin, boneMax = _extendAABB(
						boneMin,
						boneMax,
						directions[k],
						t1BoneInstance,
						t2BoneInstance
					)
				end

				boneMin:scale(boneWeight):add(vertexMin, vertexMin)
				boneMax:scale(boneWeight):add(vertexMax, vertexMax)
			end
		end

		vertexBounds[i] = { vertexMin, vertexMax }
	end

	return vertexBounds
end

--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @param animation RatScratch.Graphics.Graphics3D.Animation
--- @return RatScratch.Math.Vector3, number
function ExtendedMeshMeshlet:computeSkinnedBounds(skeleton, animation)
	--- Implementation based on "Conservative Meshlet Bounds for Robust Culling of Skinned Meshes"
	--- by Johannes Unterguggenberger, Bernhard Kerbl, Jakob Pernsteiner, and Michael Wimme
	--- URL: https://www.cg.tuwien.ac.at/research/publications/2021/unterguggenberger-2021-msh/
	--- DOI: https://doi.org/10.1111/cgf.14401

	assert(self:getIsSkinned(), "meshlet is not skinned")

	local timestamps = self:_getTimestamps(skeleton, animation)
	local center, radius = self:_calculateInitialSkinnedBounds(skeleton)

	local t1Index = 1
	while t1Index < #timestamps do
		local t1 = timestamps[t1Index]

		local t2Index =
			Search.greaterThan(timestamps, t1, _compareTime, t1Index)
		local t2 = timestamps[t2Index]

		local bounds = self:_computeVerticesBounds(skeleton, animation, t1, t2)
		if bounds then
			radius = self:_recalculateSkinnedBounds(bounds, center, radius)
		end

		t1Index = t2Index
	end

	return center, radius
end

return ExtendedMeshMeshlet
