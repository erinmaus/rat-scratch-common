local Object = require("rat-scratch-common").Object
local Resource = require("rat-scratch-resource").Resource
local ResourceLoader = require("rat-scratch-resource").ResourceLoader
local ResourceEvent = require("rat-scratch-resource").ResourceEvent
local Material = require("rat-scratch-graphics.Graphics3D.Material")

--- @generic T
--- @alias RatScratch.Pipeline.Graphics3D.PipelineScenePointer.PointerFunc<T> fun(scene: RatScratch.Pipeline.Graphics3D.PipelineScene): T

--- @generic T
--- @class RatScratch.Pipeline.Graphics3D.PipelineScenePointer<T> : RatScratch.Resource.Resource<T>
--- @field parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @field pointer RatScratch.Pipeline.Graphics3D.PipelineScenePointer.PointerFunc<T>
--- @overload fun(parent: RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>, pointer: RatScratch.Pipeline.Graphics3D.PipelineScenePointer.PointerFunc<T>): RatScratch.Resource.Resource<T>
local PipelineScenePointer = Object(Resource)

--- @generic T
--- @param self RatScratch.Pipeline.Graphics3D.PipelineScenePointer<T>
--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param pointer RatScratch.Pipeline.Graphics3D.PipelineScenePointer.PointerFunc<T>
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

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param modelIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function PipelineScenePointer.newModelPointer(parent, modelIndex)
	return PipelineScenePointer(parent, function(scene)
		return scene:getModel(modelIndex)
	end)
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param skeletonIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function PipelineScenePointer.newSkeletonPointer(parent, skeletonIndex)
	return PipelineScenePointer(parent, function(scene)
		return scene:getSkeleton(skeletonIndex)
	end)
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param modelIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function PipelineScenePointer.newModelSkeletonPointer(parent, modelIndex)
	return PipelineScenePointer(parent, function(scene)
		return scene:getModel(modelIndex):getSkeleton()
	end)
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param modelIndex integer
--- @param meshIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
function PipelineScenePointer.newModelMeshPointer(parent, modelIndex, meshIndex)
	return PipelineScenePointer(parent, function(scene)
		return scene:getModel(modelIndex):getMesh(meshIndex)
	end)
end

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param skeletonIndex integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation[]>
function PipelineScenePointer.newAnimationsPointer(parent, skeletonIndex)
	return PipelineScenePointer(parent, function(scene)
		local animations = {}
		for i = 1, scene:getAnimationCount(skeletonIndex) do
			table.insert(scene:getAnimation(skeletonIndex, i))
		end

		return animations
	end)
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
	return PipelineScenePointer(parent, function(scene)
		return scene:getAnimation(skeletonIndex, animationIndex)
	end)
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
	return PipelineScenePointer(parent, function(scene)
		return scene:getAnimation(
			scene:getModel(modelIndex):getSkeleton(),
			animationIndex
		)
	end)
end

--- @alias RatScratch.Pipeline.Graphics3D.PipelineScenePointer.PointerFunc.MaterialTextureName
--- | "albedo"
--- | "normal"
--- | "occlusion"
--- | "metalRoughness"
--- | "emissive"

--- @type table<RatScratch.Pipeline.Graphics3D.PipelineScenePointer.PointerFunc.MaterialTextureName, fun(self: RatScratch.Graphics.Graphics3D.Material): love.ImageData
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
--- @param texture RatScratch.Pipeline.Graphics3D.PipelineScenePointer.PointerFunc.MaterialTextureName
--- @return RatScratch.Resource.Resource<love.ImageData>
function PipelineScenePointer.newModelMeshMaterialTexturePointer(
	parent,
	modelIndex,
	meshIndex,
	texture
)
	local getter = TEXTURE_GETTERS[texture]

	return PipelineScenePointer(parent, function(scene)
		local material =
			scene:getModel(modelIndex):getMesh(meshIndex):getMaterial()
		if material then
			return getter(material)
		end

		return nil
	end)
end

return PipelineScenePointer
