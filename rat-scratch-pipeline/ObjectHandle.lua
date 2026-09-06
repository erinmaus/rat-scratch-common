local EventSource = require("rat-scratch-common").EventSource
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local Animation = require("rat-scratch-graphics").Graphics3D.Animation
local Animator = require("rat-scratch-graphics").Graphics3D.Animator
local Skeleton = require("rat-scratch-graphics").Graphics3D.Skeleton
local Resource = require("rat-scratch-resource").Resource
local ResourceEvent = require("rat-scratch-resource").ResourceEvent
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local ObjectHandleAnimatorProvider =
	require("rat-scratch-pipeline.ObjectHandleAnimatorProvider")
local PipelineModel = require("rat-scratch-pipeline.Graphics3D.PipelineModel")
local PipelineModelMeshPointer =
	require("rat-scratch-pipeline.Resources.PipelineModelMeshPointer")
local PipelinePointer = require("rat-scratch-pipeline.Buffer.PipelinePointer")
local PipelineScene = require("rat-scratch-pipeline.Graphics3D.PipelineScene")
local PipelineScenePointer =
	require("rat-scratch-pipeline.Resources.PipelineScenePointer")

--- @alias RatScratch.Pipeline.ObjectHandle.Pointer
--- | "object"
--- | "models"
--- | "bones"

--- @class RatScratch.Pipeline.ObjectHandle : RatScratch.Common.BaseObject
--- @field private id integer
--- @field private world RatScratch.Pipeline.World
--- @field private scene RatScratch.Pipeline.Scene
--- @field private transform love.Transform
--- @field private animatorProvider RatScratch.Pipeline.Graphics3D.ObjectHandleAnimatorProvider
--- @field private animator? RatScratch.Graphics.Graphics3D.Animator
--- @field private skeleton? RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
--- @field private animations RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>[]
--- @field private animationToResource table<RatScratch.Graphics.Graphics3D.Animation, RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>>
--- @field private models RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>[]
--- @field private resourcesByInstance table<RatScratch.Resource.Resource, true>
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.ObjectHandle>
--- @field private defaultMaterials table<RatScratch.Pipeline.Resource.PipelineModelMeshPointer, RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance>
--- @field private overrideMaterials table<RatScratch.Pipeline.Resource.PipelineModelMeshPointer, RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance>
--- @field private resourceToUniforms table<RatScratch.Resource.Resource, table<RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform, table<RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh, true>>>>
--- @field private meshUniformToResource table<RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>, table<RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform, RatScratch.Resource.Resource>>
--- @field private pointers table<RatScratch.Pipeline.ObjectHandle.Pointer, RatScratch.Pipeline.Buffer.PipelinePointer>
--- @overload fun(id: integer, world: RatScratch.Pipeline.World): RatScratch.Pipeline.ObjectHandle
local ObjectHandle = Object()

function ObjectHandle:new(id, world)
	self.id = id
	self.world = world
	self.transform = love.math.newTransform()

	self.animatorProvider = ObjectHandleAnimatorProvider(self)
	self.models = {}
	self.animations = {}
	self.animationToResource = {}
	self.resourcesByInstance = {}
	self.eventSource = EventSource(self)

	self.defaultMaterials = {}
	self.overrideMaterials = {}
	self.resourceToUniforms = {}
	self.meshUniformToResource = {}

	self.pointers = {}
end

--- @param scene RatScratch.Pipeline.Scene
function ObjectHandle:move(scene)
	if self.scene then
		self.scene:removeObject(self)
	end

	self.scene = scene
	if scene then
		scene:addObject(self)
	end
end

function ObjectHandle:getWorld()
	return self.world
end

function ObjectHandle:getScene()
	return self.scene
end

function ObjectHandle:getID()
	return self.id
end

function ObjectHandle:getTransform()
	return self.transform
end

--- @param transform love.Transform
function ObjectHandle:setTransform(transform)
	self.transform:setMatrix(transform:getMatrix())
	self.eventSource:process(ObjectHandleEvent.fromTransformed(self.transform))
end

--- @param pointer RatScratch.Pipeline.ObjectHandle.Pointer
--- @param value? RatScratch.Pipeline.Buffer.PipelinePointer
function ObjectHandle:setPointer(pointer, value)
	self.pointers[pointer] = value
end

--- @param pointer RatScratch.Pipeline.ObjectHandle.Pointer
--- @return RatScratch.Pipeline.Buffer.PipelinePointer
function ObjectHandle:getPointer(pointer)
	return self.pointers[pointer] or PipelinePointer.NULL
end

--- @param object RatScratch.Pipeline.ObjectHandle
--- @param id integer
--- @return RatScratch.Common.Search.CompareResult
function ObjectHandle.compareObjectHandleToID(object, id)
	return object.id - id
end

--- @param a RatScratch.Pipeline.ObjectHandle
--- @param b RatScratch.Pipeline.ObjectHandle
--- @return RatScratch.Common.Search.CompareResult
function ObjectHandle.compare(a, b)
	return a.id - b.id
end

--- @param a RatScratch.Pipeline.ObjectHandle
--- @param b RatScratch.Pipeline.ObjectHandle
--- @return boolean
function ObjectHandle.less(a, b)
	return a.id < b.id
end

ObjectHandle.listen, ObjectHandle.silence = EventSource.mixin("eventSource")

--- @param resource RatScratch.Resource.Resource
--- @param resourceType RatScratch.Common.BaseObject | unknown
--- @return boolean
function ObjectHandle:addResource(resource, resourceType)
	if self.resourcesByInstance[resource] then
		return false
	end

	self.resourcesByInstance[resource] = true
	self.eventSource:process(
		ObjectHandleEvent.fromResourceAdded(resource, resourceType)
	)

	return true
end

--- @param resource RatScratch.Resource.Resource
--- @param resourceType RatScratch.Common.BaseObject | unknown
--- @return boolean
function ObjectHandle:removeResource(resource, resourceType)
	if not self.resourcesByInstance[resource] then
		return false
	end

	self.resourcesByInstance[resource] = nil
	self.eventSource:process(
		ObjectHandleEvent.fromResourceRemoved(resource, resourceType)
	)

	return true
end

--- @param skeleton RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
--- @return boolean
function ObjectHandle:attachSkeleton(skeleton)
	if self.skeleton and not self:detachSkeleton() then
		return false
	end

	if not self:addResource(skeleton, Skeleton) then
		return false
	end

	skeleton:listen(ResourceEvent.MODIFY, self._onSkeletonUpdate, self)
	skeleton:listen(ResourceEvent.RELEASE, self._onSkeletonRelease, self)

	self.skeleton = skeleton
	self:_updateSkeleton(skeleton)

	return true
end

--- @private
--- @param skeleton RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function ObjectHandle:_updateSkeleton(skeleton)
	if not skeleton:getIsReady() then
		return
	end

	local previousAnimator = self.animator
	self.animator = Animator(self.animatorProvider)
	self.eventSource:process(ObjectHandleEvent.fromAnimatorAdded(self.animator))

	if previousAnimator then
		self.animator:copyFrom(previousAnimator)
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Graphics.Graphics3D.Skeleton>
--- @param skeleton RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function ObjectHandle:_onSkeletonUpdate(event, skeleton)
	self:_updateSkeleton(skeleton)
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Graphics.Graphics3D.Skeleton>
--- @param skeleton RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function ObjectHandle:_onSkeletonRelease(event, skeleton)
	if self.skeleton == skeleton then
		self:detachSkeleton()
	end
end

--- @return boolean
function ObjectHandle:detachSkeleton()
	if not self.skeleton then
		return false
	end

	if self.animations then
		for i = #self.animations, 1, -1 do
			local animation = self.animations[i]
			self:detachAnimation(animation)
		end
	end

	if not self:removeResource(self.skeleton, Skeleton) then
		return false
	end

	self.skeleton:silence(ResourceEvent.MODIFY, self._onSkeletonUpdate, self)
	self.skeleton:silence(ResourceEvent.RELEASE, self._onSkeletonRelease, self)

	if self.animator then
		self.eventSource:process(
			ObjectHandleEvent.fromAnimatorRemoved(self.animator)
		)
		self.animator = nil
	end

	self.skeleton = nil
	return true
end

--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>?
function ObjectHandle:getSkeleton()
	return self.skeleton
end

--- @param animation RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
--- @return boolean
function ObjectHandle:attachAnimation(animation)
	if not self:addResource(animation, Animation) then
		return false
	end

	animation:listen(ResourceEvent.MODIFY, self._onAnimationUpdate, self)
	animation:listen(ResourceEvent.RELEASE, self._onAnimationRelease, self)

	if animation:get() then
		self.animationToResource[animation:get()] = animation
	end

	table.insert(self.animations, animation)
	return true
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Graphics.Graphics3D.Animation>
--- @param animation RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
function ObjectHandle:_onAnimationUpdate(event, animation)
	local previousAnimation = event:getPreviousValue()
	if previousAnimation then
		self.animationToResource[previousAnimation] = nil
	end

	self.animationToResource[animation:get()] = animation

	if self.animator then
		self.animator:swapAnimation(event:getPreviousValue(), animation:get())
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Graphics.Graphics3D.Animation>
--- @param animation RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
function ObjectHandle:_onAnimationRelease(event, animation)
	self:detachAnimation(animation)
end

--- @param animations RatScratch.Pipeline.Resource.PipelineScenePointer<RatScratch.Graphics.Graphics3D.Animation[]>
--- @return boolean
function ObjectHandle:attachAnimationCollection(animations)
	if not self:addResource(animations:getParent(), PipelineScene) then
		return false
	end

	animations
		:getParent()
		:listen(ResourceEvent.MODIFY, self._onAnimationCollectionUpdate, self)
	animations
		:getParent()
		:listen(ResourceEvent.RELEASE, self._onAnimationCollectionRelease, self)
	self:_updateAnimationCollection(animations)

	return true
end

--- @private
--- @param animations RatScratch.Pipeline.Resource.PipelineScenePointer<RatScratch.Graphics.Graphics3D.Animation[]>
--- @param previousAnimations? RatScratch.Pipeline.Graphics3D.PipelineScene
function ObjectHandle:_updateAnimationCollection(animations, previousAnimations)
	if not animations:getParent():getIsReady() then
		return
	end

	local scene = animations:getParent():get()
	local count
	if previousAnimations then
		count = previousAnimations:getAnimationCount(1)
		for i = 1, count do
			local previousAnimation = previousAnimations:getAnimation(1, i)
			local previousAnimationResource =
				self.animationToResource[previousAnimation]

			local nextAnimation = scene:getAnimation(1, i)
			if nextAnimation then
				if self.animator then
					self.animator:swapAnimation(
						previousAnimation,
						nextAnimation
					)
				end
			else
				self:removeResource(previousAnimationResource, Animation)
				Table.remove(self.animations, previousAnimationResource)
			end
		end
	else
		count = 0
	end

	local nextCount = scene:getAnimationCount(1)
	for i = count + 1, nextCount do
		local nextAnimation = scene:getAnimation(1, i)

		local nextAnimationResource =
			PipelineScenePointer.newAnimationPointer(scene, 1, i)
		self:addResource(nextAnimationResource, Animation)

		self.animationToResource[nextAnimation] = nextAnimationResource
		table.insert(self.animations, nextAnimationResource)
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param animations RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
function ObjectHandle:_onAnimationCollectionUpdate(event, animations)
	self:_updateAnimationCollection(animations, event:getPreviousValue())
end

--- @private
--- @param animations RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
function ObjectHandle:_removeAnimationCollection(animations)
	if not animations:getIsReady() then
		return
	end

	local scene = animations:get()
	local count = scene:getAnimationCount(1)
	for i = 1, count do
		local animation = scene:getAnimation(1, i)
		local animationResource = self.animationToResource[animation]
		if animationResource then
			self:removeResource(animationResource, Animation)
			self.animationToResource[animation] = nil

			Table.remove(self.animations, animationResource)
		end
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param animations RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
function ObjectHandle:_onAnimationCollectionRelease(event, animations)
	if not self:removeResource(animations, PipelineScene) then
		return
	end

	self:_removeAnimationCollection(animations)
end

--- @param animation RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
--- @return boolean
function ObjectHandle:detachAnimation(animation)
	if not self:removeResource(animation, Animation) then
		return false
	end

	if animation:getIsReady() then
		self.animationToResource[animation:get()] = nil
	end

	animation:silence(ResourceEvent.MODIFY, self._onAnimationUpdate, self)
	animation:silence(ResourceEvent.RELEASE, self._onAnimationRelease, self)

	Table.remove(self.animations, animation)
	return true
end

--- @param animations RatScratch.Pipeline.Resource.PipelineScenePointer<RatScratch.Graphics.Graphics3D.Animation[]>
--- @return boolean
function ObjectHandle:detachAnimationCollection(animations)
	if not self:removeResource(animations, PipelineScene) then
		return false
	end

	self:_removeAnimationCollection(animations)
	return true
end

--- @return integer
function ObjectHandle:getAnimationCount()
	return #self.animations
end

--- @param index integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
function ObjectHandle:getAnimation(index)
	return self.animations[index]
end

--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ObjectHandle:attachModel(model)
	if not self:addResource(model, PipelineModel) then
		return
	end

	model:listen(ResourceEvent.MODIFY, self._onModelUpdate, self)
	model:listen(ResourceEvent.RELEASE, self._onModelRelease, self)

	table.insert(self.models, model)
end

--- @private
--- @param modelResource RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @param meshIndex integer
function ObjectHandle:_newDefaultMaterialInstance(modelResource, meshIndex)
	local model = modelResource:get()
	local materialPipeline = self.world:getPipeline(MaterialPipeline)

	local meshResource =
		PipelineModelMeshPointer.newModelMeshPointer(modelResource, meshIndex)
	local materialInstance = self.defaultMaterials[meshResource]
	if not materialInstance then
		materialInstance = materialPipeline:newMaterialInstance("Basic")
		self.defaultMaterials[meshResource] = materialInstance
	end

	local mesh = model:getMesh(meshIndex)
	local materialProperties = mesh:getMaterial()
	if not materialProperties then
		return
	end

	local overrideMaterial = self.overrideMaterials[meshResource]
	self.overrideMaterials[meshResource] = nil

	self:setModelMeshMaterialUniformByArguments(
		meshResource,
		"albedoFactor",
		materialProperties:getColor()
	)

	if materialProperties:getTexture() then
		self:setModelMeshMaterialUniformByArguments(
			meshResource,
			"albedoTexture",
			meshResource:getTexturePointer("albedo")
		)
	end

	self:setModelMeshMaterialUniformByArguments(
		meshResource,
		"metallicFactor",
		materialProperties:getMetal()
	)

	self:setModelMeshMaterialUniformByArguments(
		meshResource,
		"roughnessFactor",
		materialProperties:getRoughness()
	)
	if materialProperties:getMetalRoughnessTexture() then
		self:setModelMeshMaterialUniformByArguments(
			meshResource,
			"metallicRoughnessTexture",
			meshResource:getTexturePointer("metalRoughness")
		)
	end

	self:setModelMeshMaterialUniformByArguments(
		meshResource,
		"occlusionStrength",
		materialProperties:getOcclusion()
	)

	if materialProperties:getOcclusionTexture() then
		self:setModelMeshMaterialUniformByArguments(
			meshResource,
			"occlusionTexture",
			meshResource:getTexturePointer("occlusion")
		)
	end

	self:setModelMeshMaterialUniformByArguments(
		meshResource,
		"normalScale",
		materialProperties:getNormalScale()
	)

	if materialProperties:getNormalTexture() then
		self:setModelMeshMaterialUniformByArguments(
			meshResource,
			"normalTexture",
			meshResource:getTexturePointer("normal")
		)
	end

	self:setModelMeshMaterialUniformByArguments(
		meshResource,
		"emissiveFactor",
		materialProperties:getColor()
	)

	if materialProperties:getEmissiveTexture() then
		self:setModelMeshMaterialUniformByArguments(
			meshResource,
			"emissiveTexture",
			meshResource:getTexturePointer("emissive")
		)
	end

	self.overrideMaterials[meshResource] = overrideMaterial
end

--- @private
--- @param modelResource RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @param previousModel? RatScratch.Pipeline.Graphics3D.PipelineModel
function ObjectHandle:_updateModel(modelResource, previousModel)
	if not modelResource:getIsReady() then
		return
	end

	local model = modelResource:get()
	local count = model:getMeshCount()

	for i = 1, count do
		self:_newDefaultMaterialInstance(modelResource, i)
	end

	if previousModel then
		local materialPipeline = self.world:getPipeline(MaterialPipeline)
		for i = previousModel:getMeshCount(), count + 1, -1 do
			local mesh =
				PipelineModelMeshPointer.newModelMeshPointer(modelResource, i)

			if self.overrideMaterials[mesh] then
				materialPipeline:freeMaterialInstance(
					self.overrideMaterials[mesh]
				)
				self.overrideMaterials[mesh] = nil
			end

			if self.defaultMaterials[mesh] then
				materialPipeline:freeMaterialInstance(
					self.defaultMaterials[mesh]
				)
				self.defaultMaterials[mesh] = nil
			end
		end
	end
end

--- @private
--- @param modelResource RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ObjectHandle:_removeModel(modelResource)
	if not modelResource:getIsReady() then
		return
	end

	local model = modelResource:get()
	local materialPipeline = self.world:getPipeline(MaterialPipeline)
	for i = 1, model:getMeshCount() do
		local mesh =
			PipelineModelMeshPointer.newModelMeshPointer(modelResource, i)

		local uniforms = self.meshUniformToResource[mesh]
		for _, resource in pairs(uniforms) do
			self:removeResource(resource, "love.ImageData")
		end

		if self.overrideMaterials[mesh] then
			materialPipeline:freeMaterialInstance(self.overrideMaterials[mesh])
			self.overrideMaterials[mesh] = nil
		end

		if self.defaultMaterials[mesh] then
			materialPipeline:freeMaterialInstance(self.defaultMaterials[mesh])
			self.defaultMaterials[mesh] = nil
		end
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ObjectHandle:_onModelUpdate(event, model)
	self:_updateModel(model, event:getPreviousValue())
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ObjectHandle:_onModelRelease(event, model)
	self:_removeModel(model)
end

--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @param material? RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
function ObjectHandle:setModelMeshMaterial(mesh, material)
	if self.overrideMaterials[mesh] == material then
		return
	end

	if not self.overrideMaterials[mesh] and material == nil then
		return
	end

	if self.overrideMaterials[mesh] then
		self.eventSource:process(
			ObjectHandleEvent.fromMaterialRemoved(
				mesh,
				self.overrideMaterials[mesh]
			)
		)
	else
		self.eventSource:process(
			ObjectHandleEvent.fromMaterialRemoved(
				mesh,
				self.defaultMaterials[mesh]
			)
		)
	end

	self.overrideMaterials[mesh] = material
	if self.overrideMaterials[mesh] then
		self.eventSource:process(
			ObjectHandleEvent.fromMaterialAdded(
				mesh,
				self.overrideMaterials[mesh]
			)
		)
	else
		self.eventSource:process(
			ObjectHandleEvent.fromMaterialAdded(
				mesh,
				self.defaultMaterials[mesh]
			)
		)
	end
end

--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
function ObjectHandle:unsetModelMeshMaterial(mesh)
	self:setModelMeshMaterial(mesh, nil)
end

--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @return RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
function ObjectHandle:getMeshMaterial(mesh)
	return self.overrideMaterials[mesh] or self.defaultMaterials[mesh]
end

--- @private
--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @param uniform RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform
function ObjectHandle:_unbindUniformResource(mesh, uniform)
	local oldResource = self.meshUniformToResource[mesh]
		and self.meshUniformToResource[mesh][uniform]
	if not oldResource then
		return
	end

	local uniforms = self.resourceToUniforms[oldResource]
	local meshes = uniforms and uniforms[uniform]
	if meshes then
		meshes[mesh] = nil

		if next(meshes) == nil then
			uniforms[uniform] = nil
		end

		if next(uniforms) == nil then
			self.resourceToUniforms[oldResource] = nil
		end
	end

	self.meshUniformToResource[mesh][uniform] = nil
end

--- @private
--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @param uniform RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform
--- @param resource RatScratch.Resource.Resource
function ObjectHandle:_bindResourceToUniform(mesh, uniform, resource)
	do
		local uniforms = self.resourceToUniforms[resource]
		if not uniforms then
			uniforms = {}
			self.resourceToUniforms[resource] = uniforms
		end

		local meshes = uniforms[uniform]
		if not meshes then
			meshes = {}
			uniforms[uniform] = meshes
		end

		meshes[mesh] = true
	end

	do
		local uniforms = self.meshUniformToResource[mesh]
		if not uniforms then
			uniforms = {}
			self.meshUniformToResource[mesh] = uniforms
		end

		uniforms[uniform] = resource
	end

	self.uniformsDirty = true
	self.world:updateObject(self)
end

--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @param uniformKey string | integer
--- @param ... number | RatScratch.Resource.Resource<love.ImageData>
function ObjectHandle:setModelMeshMaterialUniformByArguments(
	mesh,
	uniformKey,
	...
)
	local materialInstance = self.overrideMaterials[mesh]
		or self.defaultMaterials[mesh]
	local material = materialInstance:getMaterial()
	local uniform = material:getUniform(uniformKey)

	if uniform:getFormat() == "texture" then
		local value = ...
		if value == nil then
			self:_unbindUniformResource(mesh, uniform)
		else
			--- @cast value RatScratch.Resource.Resource<love.ImageData>
			assert(
				Object.isDerived(Resource, Object.getType(value)),
				"value is not resource"
			)
			self:addResource(value, "love.ImageData")

			self:_bindResourceToUniform(mesh, uniform, value)
		end
	else
		--- @diagnostic disable-next-line: param-type-mismatch
		materialInstance:setUniformByArguments(uniformKey, ...)
	end
end

--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @param uniformKey string | integer
--- @param value number[] | RatScratch.Resource.Resource<love.ImageData>
function ObjectHandle:setModelMeshMaterialUniformByValue(
	mesh,
	uniformKey,
	value
)
	local materialInstance = self.overrideMaterials[mesh]
		or self.defaultMaterials[mesh]
	local material = materialInstance:getMaterial()
	local uniform = material:getUniform(uniformKey)

	if uniform:getFormat() == "texture" then
		if value == nil then
			self:_unbindUniformResource(mesh, uniform)
		else
			--- @cast value RatScratch.Resource.Resource<love.ImageData>
			assert(
				Object.isDerived(Resource, Object.getType(value)),
				"value is not resource"
			)
			self:addResource(value, "love.ImageData")

			self:_bindResourceToUniform(mesh, uniform, value)
		end
	else
		materialInstance:setUniformByValue(uniformKey, value)
	end
end

--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ObjectHandle:detachModel(model)
	if not self:removeResource(model, PipelineModel) then
		return
	end

	self:_removeModel(model)

	model:silence(ResourceEvent.MODIFY, self._onModelUpdate, self)
	model:silence(ResourceEvent.RELEASE, self._onModelRelease, self)

	Table.remove(self.models, model)
end

--- @private
function ObjectHandle:_tryFlushUniforms()
	if not self.uniformsDirty then
		return
	end

	local hasDirtyUniforms = false
	for mesh, uniforms in pairs(self.meshUniformToResource) do
		local material = self.overrideMaterials[mesh]
			or self.defaultMaterials[mesh]

		for uniform, resource in pairs(uniforms) do
			if resource:getIsReady() then
				material:setUniformByValue(uniform:getName(), resource:get())
			else
				hasDirtyUniforms = true
			end
		end
	end

	if not hasDirtyUniforms then
		self.uniformsDirty = false
	end
end

function ObjectHandle:flush()
	self:_tryFlushUniforms()
end

return ObjectHandle
