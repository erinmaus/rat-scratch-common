local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Table = require("rat-scratch-common").Table
local AABB = require("rat-scratch-math").Geometry3D.AABB
local Triangle = require("rat-scratch-math").Geometry3D.Triangle
local BVH = require("rat-scratch-graphics.BVH")
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local FlatTable = require("rat-scratch-commo").FlatTable
local Vector3 = require("rat-scratch-math").Vector3
local ffi = require("ffi")

--- @class RatScratch.Graphics.Graphics3D.MeshBVH.Triangle
--- @field public centroid RatScratch.Math.Vector3
--- @field public minBounds RatScratch.Math.Vector3
--- @field public maxBounds RatScratch.Math.Vector3
local MeshBVHTriangle = {}

--- @class RatScratch.Graphics.Graphics3D.MeshBVH : RatScratch.Graphics.BVH
--- @field private vertexPositions RatScratch.Common.FlatTable<number>
--- @field private indexData RatScratch.Common.FlatTable<integer>
--- @field private triangles RatScratch.Graphics.Graphics3D.MeshBVH.Triangle[]
--- @overload fun(nodeCount?: integer, objectCount?: integer): RatScratch.Graphics.Graphics3D.MeshBVH
local MeshBVH = Object(BVH)

--- @param nodeCount? integer
--- @param objectCount? integer
function MeshBVH:new(nodeCount, objectCount)
	BVH.new(self, nodeCount, objectCount)

	self.vertexPositions = FlatTable.wrap(0, 3)
	self.indexData = FlatTable.wrap(0, 3)
end

function MeshBVH:getObjectBounds(objectIndex)
	local triangle = self.triangles[objectIndex]
	return triangle.minBounds, triangle.maxBounds
end

function MeshBVH:getObjectCenter(objectIndex)
	local triangle = self.triangles[objectIndex]
	return triangle.centroid
end

do
	local _v1, _v2, _v3 = Vector3(), Vector3(), Vector3()

	--- @param objectIndex integer
	--- @param origin RatScratch.Math.Vector3
	--- @param direction RatScratch.Math.Vector3
	--- @return boolean, number
	function MeshBVH:raycastObject(objectIndex, origin, direction)
		local i, j, k = self.indexData:get(objectIndex)
		local v1, v2, v3 =
			_v1:from(self.vertexPositions:get(i + 1)),
			_v2:from(self.vertexPositions:get(j + 1)),
			_v3:from(self.vertexPositions:get(k + 1))

		return Triangle.raycast(v1, v2, v3, origin, direction)
	end
end

do
	local _vertex = {}
	local INDEX_BUFFER_FORMAT_INSTANCE = BufferFormat({
		{ location = 0, name = "triangleIndices", format = "uint32vec3" },
	}, true)

	local _position = Vector3()
	function MeshBVH:_initTriangles()
		self.triangles = Table.new(self:getObjectCount(), 0)

		local position = _position
		for i = 1, self:getObjectCount() do
			--- @type RatScratch.Graphics.Graphics3D.MeshBVH.Triangle
			local triangle = {
				minBounds = Vector3(),
				maxBounds = Vector3(),
				centroid = Vector3(),
			}

			local ti, tj, tk = self.indexData:get(i)
			triangle.centroid:from(self.vertexPositions:get(ti))
			triangle.minBounds:from(self.vertexPositions:get(ti))
			triangle.maxBounds:from(self.vertexPositions:get(ti))

			AABB.expand(
				triangle.minBounds,
				triangle.maxBounds,
				position:from(self.vertexPositions:get(tj))
			)
			triangle.centroid:add(position, triangle.centroid)

			AABB.expand(
				triangle.minBounds,
				triangle.maxBounds,
				position:from(self.vertexPositions:get(tk))
			)
			triangle.centroid:add(position, triangle.centroid)

			triangle.centroid:scale(1 / 3)

			table.insert(self.triangles, triangle)
		end
	end

	--- @param vertexFormat RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
	--- @param vertexData love.ByteData
	--- @param indexData love.ByteData
	function MeshBVH.fromData(vertexFormat, vertexData, indexData)
		local vertexFormatInstance = BufferFormat.get(vertexFormat)
		assert(
			vertexFormatInstance:hasAttribute("VertexPosition"),
			"vertex format missing 'VertexPosition'"
		)

		local indexFormatInstance = INDEX_BUFFER_FORMAT_INSTANCE
		local vertexCount = vertexData:getSize()
			/ vertexFormatInstance:getStride()

		local vertex = _vertex
		Table.clear(vertex)

		local indexCount = indexData:getSize() / ffi.sizeof("uint32_t")
		local triangleCount = indexCount / 3

		local bvh = MeshBVH(2 * triangleCount, triangleCount)
		bvh.vertexPositions:resize(vertexCount)
		bvh.indexData:resize(triangleCount)

		local positionCount, positionOffset =
			vertexFormatInstance:getCountOffset("VertexPosition")
		local positionI, positionJ =
			positionOffset, positionOffset + positionCount - 1
		for i = 1, vertexCount do
			local offset = (i - 1) * vertexFormatInstance:getStride()
			BufferFormat.copyFromByteDataToFlatTable(
				vertexFormatInstance,
				offset,
				1,
				1,
				vertexData,
				vertex
			)

			local x, y, z = Table.unpack(vertex, positionI, positionJ)

			bvh.vertexPositions:set(i, x or 0, y or 0, z or 0)
		end

		BufferFormat.copyFromByteDataToFlatTable(
			indexFormatInstance,
			0,
			1,
			triangleCount,
			indexData,
			bvh.indexData:getArray()
		)

		bvh:_initTriangles()

		return bvh
	end

	--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
	function MeshBVH.fromMeshDefinition(meshDefinition)
		assert(
			type(meshDefinition.indices) == "table",
			"indices must be table of indices"
		)
		assert(
			type(meshDefinition.vertices) == "table",
			"vertices must be table of vertex data"
		)

		local triangleCount = #meshDefinition.indices / 3

		local bvh = MeshBVH(2 * triangleCount, triangleCount)
		bvh.vertexPositions:resize(#meshDefinition.vertices)
		bvh.indexData:resize(#meshDefinition.indices)

		local vertexFormatInstance = BufferFormat.get(meshDefinition.format)
		assert(
			vertexFormatInstance:hasAttribute("VertexPosition"),
			"vertex format missing 'VertexPosition'"
		)

		local positionCount, positionOffset =
			vertexFormatInstance:getCountOffset("VertexPosition")
		for i = 1, #meshDefinition.vertices do
			local vertex = meshDefinition.vertices[i]
			Table.transfer(
				bvh.vertexPositions:getArray(),
				vertex,
				positionCount,
				Table.indexToStride(i, 3),
				positionOffset
			)
		end

		Table.transfer(
			bvh.indexData:getArray(),
			--- @diagnostic disable-next-line: param-type-mismatch
			meshDefinition.indices,
			#meshDefinition.indices
		)

		return bvh
	end
end

return MeshBVH
