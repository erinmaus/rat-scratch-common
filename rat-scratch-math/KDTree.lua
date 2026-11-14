local Object = require("rat-scratch-common").Object
local KDTreeNode = require("rat-scratch-math.KDTreeNode")
local ObjectPool = require("rat-scratch-common.ObjectPool")
local Table = require("rat-scratch-common.Table")

--- @alias RatScratch.Math.KDTree.Axis "x" | "y" | "z" | string
--- @alias RatScratch.Math.KDTree.Dimension 1 | 2 | 3 | integer

--- @generic T
--- @class RatScratch.Math.KDTree<T> : RatScratch.Common.BaseObject
--- @field private root RatScratch.Math.KDTreeNode<T> | false
--- @field private dimensions RatScratch.Math.KDTree.Dimension
--- @field private nodePool RatScratch.Common.ObjectPool<RatScratch.Math.KDTreeNode<T>>
--- @overload fun<T>(dimensions: RatScratch.Math.KDTree.Dimension): RatScratch.Math.KDTree<T>
local KDTree = Object()

--- @type table<RatScratch.Math.KDTree.Dimension, RatScratch.Math.KDTree.Axis>
KDTree.DEFAULT_AXIS = {
	"x",
	"y",
	"z",
}

--- @type table<RatScratch.Math.KDTree.Axis, RatScratch.Math.KDTree.Dimension>
KDTree.DEFAULT_DIMENSION = {
	x = 1,
	y = 2,
	z = 3,
}

--- @param dimensions RatScratch.Math.KDTree.Dimension
function KDTree:new(dimensions)
	self.root = false
	self.dimensions = dimensions
end

function KDTree:getDimensions()
	return self.dimensions
end

--- @param n integer
--- @return RatScratch.Math.KDTree.Axis
function KDTree:getAxis(n)
	return KDTree.DEFAULT_AXIS[n]
end

--- @param currentAxis RatScratch.Math.KDTree.Axis
--- @return RatScratch.Math.KDTree.Axis
function KDTree:nextAxis(currentAxis)
	local d = KDTree.DEFAULT_DIMENSION[currentAxis]
	return KDTree.DEFAULT_AXIS[Table.wrapIndex(d + 1, self.dimensions)]
end

--- @generic T
--- @param self RatScratch.Math.KDTree<T>
--- @param a T
--- @param b T
--- @return number
function KDTree:distance(a, b)
	return self:ABSTRACT()
end

--- @generic T
--- @param self RatScratch.Math.KDTree<T>
--- @param a T
--- @param b T
--- @return number
function KDTree:fastDistance(a, b)
	return self:ABSTRACT()
end

--- @generic T
--- @param self RatScratch.Math.KDTree<T>
--- @param axis RatScratch.Math.KDTree.Axis | RatScratch.Math.KDTree.Dimension
--- @param a T
--- @param b T
--- @return number
function KDTree:difference(axis, a, b)
	return self:ABSTRACT()
end

--- @generic T
--- @param self RatScratch.Math.KDTree<T>
--- @param axis RatScratch.Math.KDTree.Axis | RatScratch.Math.KDTree.Dimension
--- @param a T
--- @param b T
--- @return RatScratch.Common.Search.CompareResult
function KDTree:compare(axis, a, b)
	return self:ABSTRACT()
end

do
	--- @type RatScratch.Math.Vector3[]
	local _cachedArray = {}

	--- @type RatScratch.Math.KDTree
	local _tree = nil

	--- @type RatScratch.Math.KDTree.Axis
	local _axis = nil

	--- @generic T
	--- @param a T
	--- @param b T
	--- @return RatScratch.Common.Search.CompareResult
	local function _compareValue(a, b)
		return _tree:compare(_axis, a, b)
	end

	--- @private
	--- @generic T
	--- @param tree RatScratch.Math.KDTree<T>
	--- @param points RatScratch.Math.Vector3[]
	--- @param left integer
	--- @param right integer
	--- @param axis RatScratch.Math.KDTree.Axis
	--- @return RatScratch.Math.KDTreeNode<T> | nil
	function KDTree._build(tree, points, left, right, axis)
		if left > right then
			return nil
		end

		_axis = axis
		_tree = tree
		local func = _compareValue

		local mid = math.floor((left + right) / 2)
		Table.select(points, left, right, mid, func)

		local nextAxis = tree:nextAxis(axis)

		local result = tree.nodePool:pop(points[mid], axis)
		result:setChildren(
			KDTree._build(tree, points, left, mid - 1, nextAxis),
			KDTree._build(tree, points, mid + 1, right, nextAxis)
		)

		return result
	end

	--- @generic T
	--- @param values T[]
	--- @param tree RatScratch.Math.KDTree<T>
	--- @return RatScratch.Math.KDTree<T>
	function KDTree.build(tree, values)
		assert(#values >= 1, "expected at least one value")

		local t = Table.clone(values, _cachedArray)

		local result = KDTree._build(tree, t, 1, #t, tree:getAxis(1))
		tree.root = result or false

		Table.clear(t)

		return tree
	end
end

return KDTree
