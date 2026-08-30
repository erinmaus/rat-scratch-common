local Object = require("rat-scratch-common").Object
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table
local Resource = require("rat-scratch-resource").Resource
local ResourceLoader = require("rat-scratch-resource").ResourceLoader
local ResourceEvent = require("rat-scratch-resource").ResourceEvent
local Material = require("rat-scratch-graphics.Graphics3D.Material")

--- @generic T
--- @alias RatScratch.Pipeline.Resource.PipelineScenePointer.PointerFunc<T> fun(scene: RatScratch.Pipeline.Graphics3D.PipelineScene): T

--- @alias RatScratch.Pipeline.Resource.PipelineScenePointer.impl.CachedPointer {
---   arguments: number[],
---   resource: RatScratch.Pipeline.Resource.PipelineScenePointer,
--- }

--- @alias RatScratch.Pipeline.Resource.PipelineScenePointer.impl.CachedPointerPool table<function, RatScratch.Pipeline.Resource.PipelineScenePointer.impl.CachedPointer[]>

--- @param element RatScratch.Pipeline.Resource.PipelineScenePointer.impl.CachedPointer
--- @param value number[]
--- @return RatScratch.Common.Search.CompareResult
local function _compareCachedPointer(element, value)
	local argumentCount = #element.arguments - #value
	if argumentCount ~= 0 then
		return argumentCount
	end

	for i = 1, #element.arguments do
		local argument = element.arguments[i] - value[i]
		if argument ~= 0 then
			return argument
		end
	end

	return 0
end

--- @generic T
--- @class RatScratch.Pipeline.Resource.PipelineScenePointer<T> : RatScratch.Resource.Resource<T>
--- @field parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @field pointer RatScratch.Pipeline.Resource.PipelineScenePointer.PointerFunc<T>
--- @overload fun(parent: RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>, pointer: RatScratch.Pipeline.Resource.PipelineScenePointer.PointerFunc<T>): RatScratch.Resource.Resource<T>
local PipelineScenePointer = Object(Resource)

--- @type table<RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>, RatScratch.Pipeline.Resource.PipelineScenePointer.impl.CachedPointerPool>
PipelineScenePointer.POOL = setmetatable({}, { __mode = "k" })

--- @generic T
--- @param self RatScratch.Pipeline.Resource.PipelineScenePointer<T>
--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param pointer RatScratch.Pipeline.Resource.PipelineScenePointer.PointerFunc<T>
function PipelineScenePointer:new(parent, pointer)
	Resource.new(self, ResourceLoader.newID())

	self.parent = parent
	self.pointer = pointer

	self.modifyID =
		parent:listen(ResourceEvent.MODIFY, self._onParentModify, self)
	self.releaseID =
		parent:listen(ResourceEvent.MODIFY, self._onParentRelease, self)
end

function PipelineScenePointer:getParent()
	return self.parent
end

function PipelineScenePointer:free()
	Resource.free(self)
	self.parent:silence(self.modifyID)
	self.parent:silence(self.releaseID)
end

--- @private
function PipelineScenePointer:_onParentModify()
	local success, result = pcall(self.pointer, self.parent:get())
	if success then
		self:set(result)
	else
		self:set(nil)
	end
end

--- @private
function PipelineScenePointer:_onParentRelease()
	self:release()
end

do
	local _cachedArguments = {}

	--- @private
	--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
	--- @param func function
	--- @param ... integer
	--- @return integer, RatScratch.Pipeline.Resource.PipelineScenePointer?
	function PipelineScenePointer._getPooledPointer(parent, func, ...)
		local arguments = _cachedArguments
		Table.clear(arguments)
		Table.append(arguments, ...)

		local parentPool = PipelineScenePointer.POOL[parent]
		if not parentPool then
			parentPool = {}
			PipelineScenePointer.POOL[parent] = parentPool
		end

		local pointerPool = parentPool[func]
		if not pointerPool then
			pointerPool = {}
			parentPool[func] = pointerPool
		end

		local index =
			Search.lessThanEqual(pointerPool, arguments, _compareCachedPointer)
		if
			pointerPool[index]
			and _compareCachedPointer(pointerPool[index], arguments) == 0
		then
			return index, pointerPool[index].resource
		end

		return index, nil
	end

	--- @private
	--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
	--- @param func function
	--- @param index integer
	--- @param resource RatScratch.Pipeline.Resource.PipelineScenePointer
	--- @param ... integer
	function PipelineScenePointer._setPooledPointer(
		parent,
		func,
		index,
		resource,
		...
	)
		local parentPool = PipelineScenePointer.POOL[parent]
		if not parentPool then
			parentPool = {}
			PipelineScenePointer.POOL[parent] = parentPool
		end

		local pointerPool = parentPool[func]
		if not pointerPool then
			pointerPool = {}
			parentPool[func] = pointerPool
		end

		table.insert(pointerPool, index + 1, {
			arguments = { ... },
			resource = resource,
		})

		return resource
	end
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param modelIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function PipelineScenePointer.newModelPointer(parent, modelIndex)
	local index, result = PipelineScenePointer._getPooledPointer(
		parent,
		PipelineScenePointer.newModelPointer,
		modelIndex
	)
	if not result then
		return PipelineScenePointer._setPooledPointer(
			parent,
			PipelineScenePointer.newModelPointer,
			index,
			PipelineScenePointer(parent, function(scene)
				return scene:getModel(modelIndex)
			end),
			modelIndex
		)
	end

	return result
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param skeletonIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function PipelineScenePointer.newSkeletonPointer(parent, skeletonIndex)
	local index, result = PipelineScenePointer._getPooledPointer(
		parent,
		PipelineScenePointer.newSkeletonPointer,
		skeletonIndex
	)
	if not result then
		return PipelineScenePointer._setPooledPointer(
			parent,
			PipelineScenePointer.newSkeletonPointer,
			index,
			PipelineScenePointer(parent, function(scene)
				return scene:getSkeleton(skeletonIndex)
			end),
			skeletonIndex
		)
	end

	return result
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param modelIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function PipelineScenePointer.newModelSkeletonPointer(parent, modelIndex)
	local index, result = PipelineScenePointer._getPooledPointer(
		parent,
		PipelineScenePointer.newModelSkeletonPointer,
		modelIndex
	)
	if not result then
		return PipelineScenePointer._setPooledPointer(
			parent,
			PipelineScenePointer.newModelSkeletonPointer,
			index,
			PipelineScenePointer(parent, function(scene)
				return scene:getModel(modelIndex):getSkeleton()
			end),
			modelIndex
		)
	end

	return result
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param modelIndex integer
--- @param meshIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
function PipelineScenePointer.newModelMeshPointer(parent, modelIndex, meshIndex)
	local index, result = PipelineScenePointer._getPooledPointer(
		parent,
		PipelineScenePointer.newModelMeshPointer,
		modelIndex,
		meshIndex
	)
	if not result then
		return PipelineScenePointer._setPooledPointer(
			parent,
			PipelineScenePointer.newModelMeshPointer,
			index,
			PipelineScenePointer(parent, function(scene)
				return scene:getModel(modelIndex):getMesh(meshIndex)
			end),
			modelIndex,
			meshIndex
		)
	end

	return result
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param skeletonIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation[]>
function PipelineScenePointer.newAnimationsPointer(parent, skeletonIndex)
	local index, result = PipelineScenePointer._getPooledPointer(
		parent,
		PipelineScenePointer.newAnimationsPointer,
		skeletonIndex
	)
	if not result then
		return PipelineScenePointer._setPooledPointer(
			parent,
			PipelineScenePointer.newAnimationsPointer,
			index,
			PipelineScenePointer(parent, function(scene)
				local animations = {}
				for i = 1, scene:getAnimationCount(skeletonIndex) do
					table.insert(
						animations,
						scene:getAnimation(skeletonIndex, i)
					)
				end
				return animations
			end),
			skeletonIndex
		)
	end

	return result
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param skeletonIndex integer
--- @param animationIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
function PipelineScenePointer.newAnimationPointer(
	parent,
	skeletonIndex,
	animationIndex
)
	local index, result = PipelineScenePointer._getPooledPointer(
		parent,
		PipelineScenePointer.newAnimationPointer,
		skeletonIndex,
		animationIndex
	)
	if not result then
		return PipelineScenePointer._setPooledPointer(
			parent,
			PipelineScenePointer.newAnimationPointer,
			index,
			PipelineScenePointer(parent, function(scene)
				return scene:getAnimation(skeletonIndex, animationIndex)
			end),
			skeletonIndex,
			animationIndex
		)
	end

	return result
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param modelIndex integer
--- @param animationIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
function PipelineScenePointer.newModelAnimationPointer(
	parent,
	modelIndex,
	animationIndex
)
	local index, result = PipelineScenePointer._getPooledPointer(
		parent,
		PipelineScenePointer.newModelAnimationPointer,
		modelIndex,
		animationIndex
	)
	if not result then
		return PipelineScenePointer._setPooledPointer(
			parent,
			PipelineScenePointer.newModelAnimationPointer,
			index,
			PipelineScenePointer(parent, function(scene)
				return scene:getAnimation(
					scene:getModel(modelIndex):getSkeleton(),
					animationIndex
				)
			end),
			modelIndex,
			animationIndex
		)
	end

	return result
end

--- @alias RatScratch.Pipeline.Resource.PipelineScenePointer.PointerFunc.MaterialTextureName
--- | "albedo"
--- | "normal"
--- | "occlusion"
--- | "metalRoughness"
--- | "emissive"

--- @type table<RatScratch.Pipeline.Resource.PipelineScenePointer.PointerFunc.MaterialTextureName, fun(self: RatScratch.Graphics.Graphics3D.Material): love.ImageData
local TEXTURE_GETTERS = {
	albedo = Material.getTexture,
	normal = Material.getNormalTexture,
	occlusion = Material.getOcclusionTexture,
	metalRoughness = Material.getMetalRoughnessTexture,
	emissive = Material.getEmissiveTexture,
}

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param modelIndex integer
--- @param meshIndex integer
--- @param texture RatScratch.Pipeline.Resource.PipelineScenePointer.PointerFunc.MaterialTextureName
--- @return RatScratch.Resource.Resource<love.ImageData>
function PipelineScenePointer.newModelMeshMaterialTexturePointer(
	parent,
	modelIndex,
	meshIndex,
	texture
)
	local getter = TEXTURE_GETTERS[texture]

	local index, result = PipelineScenePointer._getPooledPointer(
		parent,
		PipelineScenePointer.newModelMeshMaterialTexturePointer,
		modelIndex,
		meshIndex,
		texture
	)
	if not result then
		return PipelineScenePointer._setPooledPointer(
			parent,
			PipelineScenePointer.newModelMeshMaterialTexturePointer,
			index,
			PipelineScenePointer(parent, function(scene)
				local material =
					scene:getModel(modelIndex):getMesh(meshIndex):getMaterial()
				if material then
					return getter(material)
				end

				return nil
			end),
			modelIndex,
			meshIndex,
			texture
		)
	end

	return result
end

return PipelineScenePointer
