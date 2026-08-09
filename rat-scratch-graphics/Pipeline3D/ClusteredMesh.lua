local Object = require("rat-scratch-common").Object
local ObjectPool = require("rat-scratch-common").ObjectPool
local Vector3 = require("rat-scratch-math").Vector3
local KDTreeNode = require("rat-scratch-math").KDTreeNode
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local Table = require("rat-scratch-common").Table
local TablePool = require("rat-scratch-common.TablePool")

--- @class RatScratch.Graphics.Pipeline3D.ClusteredMesh.Options
--- @field public maxTriangles? integer
local ClusteredMeshOptions = {}

local DefaultClusteredMeshOptions = {
	maxTriangles = 64,
}

--- @class RatScratch.Graphics.Pipeline3D.ClusteredMeshDefinition
--- @field public mesh RatScratch.Graphics.Graphics3D.MeshDefinition
--- @field public clusters integer[][]
local ClusteredMeshDefinition = {}

--- @class RatScratch.Graphics.Pipeline3D.ClusteredMesh : RatScratch.Common.BaseObject
--- @overload fun(mesh: RatScratch.Graphics.Graphics3D.MeshDefinition, options?: RatScratch.Graphics.Pipeline3D.ClusteredMesh.Options): RatScratch.Graphics.Pipeline3D.ClusteredMesh
--- @field private inputMesh RatScratch.Graphics.Graphics3D.MeshDefinition
--- @field private options { maxTriangles: integer }
--- @field private result RatScratch.Graphics.Pipeline3D.ClusteredMeshDefinition
local ClusteredMesh = Object()

--- @param mesh RatScratch.Graphics.Graphics3D.MeshDefinition
--- @param options RatScratch.Graphics.Pipeline3D.ClusteredMesh.Options
function ClusteredMesh:new(mesh, options)
	self.inputMesh = mesh
	self.result = {
		mesh = mesh,
		clusters = {},
	}
	self.options = {
		maxTriangles = options and options.maxTriangles
			or DefaultClusteredMeshOptions.maxTriangles,
	}

	self:_transform()
end

function ClusteredMesh:getDefinition()
	return self.result
end

do
	local _trianglePool = TablePool()
	local _pointPool = ObjectPool(Vector3)
	local _nodePool = ObjectPool(KDTreeNode)
	local _points = {}
	local _pointToTriangle = {}
	local _triangleToPoint = {}
	local _vertexTriangles = {}
	local _triangles = {}
	local INVERSE_TRIANGLE_POINT_COUNT = 1 / 3

	local _connectedTriangles, _visitedTriangles = {}, {}
	local function _searchNearestConnectedUnvisited(node)
		local triangle = _pointToTriangle[node:getPoint()]
		return _connectedTriangles[triangle] and not _visitedTriangles[triangle]
	end

	local function _searchNearestUnvisited(node)
		local triangle = _pointToTriangle[node:getPoint()]
		return not _visitedTriangles[triangle]
	end

	--- @private
	function ClusteredMesh:_prepare()
		local pointPool = _pointPool:reset()
		local nodePool = _nodePool:reset()
		local trianglePool = _trianglePool:reset()

		local vertexTriangles = _vertexTriangles
		local triangles = _triangles

		local points = _points
		local pointToTriangle = _pointToTriangle
		local triangleToPoint = _triangleToPoint
		local inverseTrianglePointCount = INVERSE_TRIANGLE_POINT_COUNT

		local count, offset = BufferFormat.getFormatAttributeCountOffset(
			self.inputMesh.format,
			"VertexPosition"
		)
		assert(count and offset, "mesh does not have VertexPosition attribute")

		local indices = self.inputMesh.indices
		local vertices = self.inputMesh.vertices

		local k1, k2 = offset, offset + count - 1
		for i = 1, #indices, 3 do
			local a = indices[i]
			local b = indices[i + 1]
			local c = indices[i + 2]

			local s = vertices[a + 1]
			local t = vertices[b + 1]
			local p = vertices[c + 1]

			local u = pointPool:pop(Table.unpack(s, k1, k2))
			local v = pointPool:pop(Table.unpack(t, k1, k2))
			local w = pointPool:pop(Table.unpack(p, k1, k2))

			local sum = pointPool:pop()
			local point = u:add(v, sum)
				:add(w, sum)
				:scale(inverseTrianglePointCount, pointPool:pop())

			local triangle = trianglePool:pop()
			triangle[1], triangle[2], triangle[3] = a, b, c
			table.insert(triangles, triangle)

			for _, index in ipairs(triangle) do
				local vt = vertexTriangles[index]
				if not vt then
					vt = _trianglePool:pop()
					vertexTriangles[index] = vt
				end

				table.insert(vt, triangle)
			end

			pointToTriangle[point] = triangle
			triangleToPoint[triangle] = point
			table.insert(points, point)
		end

		return KDTreeNode.build(points, 3, nodePool), triangles, vertexTriangles
	end

	--- @private
	--- @param triangleCenters RatScratch.Math.KDTreeNode
	function ClusteredMesh:_split(triangleCenters)
		local pointToTriangle = _pointToTriangle
		local triangleToPoint = _triangleToPoint
		local vertexTriangles = _vertexTriangles
		local triangles = _triangles

		local maxCount = self.options.maxTriangles * 3
		local clusters = self.result.clusters

		local connectedTriangles = _connectedTriangles
		local visitedTriangles = _visitedTriangles

		--- @type RatScratch.Math.KDTreeNode | nil
		local currentRoot = triangleCenters

		local p = triangleToPoint[triangles[1]]
		repeat
			local currentClusterIndices = Table.new(maxCount, 0)

			Table.clear(connectedTriangles)

			local n = p
			while currentRoot and n and #currentClusterIndices < maxCount do
				local t = pointToTriangle[n]
				visitedTriangles[t] = true

				for i = 1, 3 do
					local index = t[i]
					local triangles = vertexTriangles[index]

					for _, o in ipairs(triangles) do
						connectedTriangles[o] = true
					end
				end

				local nextRoot, c = currentRoot:remove(n)
				if c then
					local triangle = pointToTriangle[c]

					Table.transfer(
						currentClusterIndices,
						triangle,
						3,
						#currentClusterIndices + 1,
						1
					)
				end

				currentRoot = nextRoot

				local node = currentRoot
					and c
					and currentRoot:search(p, _searchNearestConnectedUnvisited)
				n = node and node:getPoint()

				if not n and currentRoot then
					local node = currentRoot:search(p, _searchNearestUnvisited)
					n = node and node:getPoint()
				end
			end

			if #currentClusterIndices < maxCount then
				for _ = #currentClusterIndices + 1, maxCount do
					table.insert(currentClusterIndices, 0)
				end
			end

			table.insert(clusters, currentClusterIndices)

			p = n
		until not (p and currentRoot)

		Table.clear(visitedTriangles)
		Table.clear(connectedTriangles)
	end

	--- @private
	function ClusteredMesh:_transform()
		local points = _points
		local pointToTriangle = _pointToTriangle
		local triangleToPoint = _triangleToPoint
		local vertexTriangles = _vertexTriangles
		local triangles = _triangles

		local triangleCenters = self:_prepare()
		self:_split(triangleCenters)

		Table.clear(points)
		Table.clear(pointToTriangle)
		Table.clear(triangleToPoint)
		Table.clear(vertexTriangles)
		Table.clear(triangles)
	end
end

return ClusteredMesh
