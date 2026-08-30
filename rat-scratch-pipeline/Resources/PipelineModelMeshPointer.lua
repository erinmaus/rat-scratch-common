local Object = require("rat-scratch-common").Object
local Resource = require("rat-scratch-resource").Resource
local ResourceEvent = require("rat-scratch-resource").ResourceEvent
local ResourceLoader = require("rat-scratch-resource").ResourceLoader
local PipelineScene = require("rat-scratch-pipeline.Graphics3D.PipelineScene")
local PipelineScenePointer =
	require("rat-scratch-pipeline.Resources.PipelineScenePointer")

--- @class RatScratch.Pipeline.Resource.PipelineModelMeshPointer : RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @field parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @field index integer
--- @overload fun(parent: RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>, index: integer): RatScratch.Resource.Resource<T>
local PipelineModelMeshPointer = Object(Resource)

--- @type table<RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>, table<integer, RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>>>
PipelineModelMeshPointer.MESH_POOL = setmetatable({}, { __mode = "k" })

--- @type table<RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>, table<string, RatScratch.Pipeline.Resource.PipelineScenePointer<love.ImageData>>>
PipelineModelMeshPointer.TEXTURE_POOL = setmetatable({}, { __mode = "k" })

--- @type table<RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>, RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>>
PipelineModelMeshPointer.SCENES_POOL = setmetatable({}, { __mode = "k" })

--- @param parent RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @param index integer
function PipelineModelMeshPointer:new(parent, index)
	Resource.new(self, ResourceLoader.newID())

	self.parent = parent
	self.index = index
end

function PipelineModelMeshPointer:getParent()
	return self.parent
end

function PipelineModelMeshPointer:getIndex()
	return self.index
end

--- @param texture RatScratch.Pipeline.Resource.PipelineScenePointer.PointerFunc.MaterialTextureName
--- @return RatScratch.Resource.ResourceLoader<love.ImageData>
function PipelineModelMeshPointer:getTexturePointer(texture)
	if not self.parent:getIsReady() then
		return nil
	end

	local pointer = PipelineModelMeshPointer.TEXTURE_POOL[self]
	if not pointer then
		pointer = {}
		PipelineModelMeshPointer.TEXTURE_POOL[self] = pointer
	end

	if pointer[texture] then
		return pointer
	end

	local scene = PipelineModelMeshPointer.SCENES_POOL[self.parent]
	if not scene then
		scene = Resource(ResourceLoader.newID())
		scene:set(PipelineScene(self.parent:get()))

		self.parent:listen(ResourceEvent.MODIFY, self._modifyScene, self)
		self.parent:listen(ResourceEvent.RELEASE, self._releaseScene, self)
		self.parent:listen(ResourceEvent.FREE, self._freeScene, self)
	end

	pointer[texture] = PipelineScenePointer.newModelMeshMaterialTexturePointer(
		scene,
		1,
		self.index,
		texture
	)
	return pointer[texture]
end

--- @private
function PipelineModelMeshPointer:_modifyScene()
	local scene = PipelineModelMeshPointer.SCENES_POOL[self.parent]
	if scene then
		scene:set(PipelineScene(self.parent))
	end
end

--- @private
function PipelineModelMeshPointer:_releaseScene()
	local scene = PipelineModelMeshPointer.SCENES_POOL[self.parent]
	if scene then
		scene:release()
	end
end

--- @private
function PipelineModelMeshPointer:_freeScene()
	local scene = PipelineModelMeshPointer.SCENES_POOL[self.parent]
	if scene then
		scene:free()

		self.parent:silence(ResourceEvent.MODIFY, self._modifyScene, self)
		self.parent:silence(ResourceEvent.FREE, self._freeScene, self)
		self.parent:silence(ResourceEvent.RELEASE, self._releaseScene, self)
	end
end

--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @param index integer
--- @return RatScratch.Pipeline.Resource.PipelineModelMeshPointer
function PipelineModelMeshPointer.newModelMeshPointer(model, index)
	local meshes = PipelineModelMeshPointer.MESH_POOL[model]
	if not meshes then
		meshes = {}
		PipelineModelMeshPointer.MESH_POOL[model] = meshes
	end

	local mesh = meshes[index]
	if mesh then
		return mesh
	end

	mesh = PipelineModelMeshPointer(model, index)
	meshes[index] = mesh

	return mesh
end

return PipelineModelMeshPointer
