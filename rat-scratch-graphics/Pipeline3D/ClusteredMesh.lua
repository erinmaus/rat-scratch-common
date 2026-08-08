local Object = require("rat-scratch-common").Object
local ObjectPool = require("rat-scratch-common").ObjectPool
local Vector3 = require("rat-scratch-math").Vector3
local KDTreeNode = require("rat-scratch-math").KDTreeNode
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local Table = require("rat-scratch-common").Table

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
	local _pointPool = ObjectPool(Vector3)
	local _nodePool = ObjectPool(KDTreeNode)
	local _points = {}
	local _pointsToTriangle = {}
	local INVERSE_TRIANGLE_POINT_COUNT = 1 / 3

	--- @private
	function ClusteredMesh:_prepare()
		local pointPool = _pointPool:reset()
		local nodePool = _nodePool:reset()

		local points = _points
		local pointsToTriangle = _pointsToTriangle
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

			pointsToTriangle[point] = i
			table.insert(points, point)
		end

		return KDTreeNode.build(points, 3, nodePool)
	end

	--- @private
	--- @param triangleCenters RatScratch.Math.KDTreeNode
	function ClusteredMesh:_split(triangleCenters)
		local pointsToTriangle = _pointsToTriangle

		local currentClusterIndices
		local maxCount = self.options.maxTriangles * 3

		local clusters = self.result.clusters
		local indices = self.inputMesh.indices

		--- @type RatScratch.Math.KDTreeNode | nil
		local currentRoot = triangleCenters
		repeat
			currentClusterIndices = Table.new(maxCount, 0)

			local p = next(pointsToTriangle)
			if not p then
				break
			end

			local n = p
			while currentRoot and p and #currentClusterIndices < maxCount do
				local nextRoot, c = currentRoot:remove(n)

				if c then
					local index = pointsToTriangle[c]
					pointsToTriangle[c] = nil

					--- @cast indices integer[]
					Table.transfer(
						currentClusterIndices,
						indices,
						3,
						#currentClusterIndices + 1,
						index
					)
				end

				currentRoot = nextRoot
				n = currentRoot and c and currentRoot:search(p):getPoint()
			end

			if #currentClusterIndices < maxCount then
				for _ = #currentClusterIndices + 1, maxCount do
					table.insert(currentClusterIndices, 0)
				end
			end

			table.insert(clusters, currentClusterIndices)
		until not currentRoot
	end

	--- @private
	function ClusteredMesh:_transform()
		local points = _points
		local pointsToTriangle = _pointsToTriangle

		local triangleCenters = self:_prepare()
		self:_split(triangleCenters)

		Table.clear(points)
		Table.clear(pointsToTriangle)
	end
end

return ClusteredMesh
