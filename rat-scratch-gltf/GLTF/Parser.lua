local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Path = require("rat-scratch-common").Path
local GLTF = require("rat-scratch-gltf.GLTF.Types")
local GLTFAccessor = require("rat-scratch-gltf.GLTF.Accessor")
local GLTFSparseAccessor = require("rat-scratch-gltf.GLTF.SparseAccessor")
local GLTFAttributes = require("rat-scratch-gltf.GLTF.Attributes")
local Quaternion = require("rat-scratch-math").Quaternion
local Vector3 = require("rat-scratch-math").Vector3

--- @class RatScratch.GLTF.GLTFParser : RatScratch.Common.BaseObject
--- @field public filename string
--- @field public root RatScratch.GLTF.GLTF
--- @field public data? love.Data
--- @field public buffers table<integer, love.Data>
--- @field public bufferViews table<integer, love.Data>
--- @field public accessors table<integer, RatScratch.GLTF.GLTFAccessor | RatScratch.GLTF.GLTFSparseAccessor>
--- @field public animationsNodesMap table<integer, table<integer, true>>
--- @field public images table<integer, love.ImageData>
--- @field public attributes RatScratch.GLTF.GLTFAttributes
local GLTFParser = Object()

local DEFAULT_WHITE_IMAGE_DATA = love.image.newImageData(1, 1)
DEFAULT_WHITE_IMAGE_DATA:setPixel(0, 0, 1, 1, 1, 1)

--- @param filename string
--- @param json RatScratch.GLTF.GLTF
--- @param binaryData? love.Data
function GLTFParser:new(filename, json, binaryData)
	assert(
		json and json.asset and json.asset.version == GLTF.GLTF_VERSION,
		"not valid GLTF JSON; expected %s, got %s",
		GLTF.GLTF_VERSION, json and json.asset and json.asset.version or "(nothing)"
	)

	self.filename = filename
	self.root = json
	self.data = binaryData and love.data.newByteData(binaryData)
	self.buffers = {}
	self.bufferViews = {}
	self.images = {}
	self.animationsNodesMap = {}
	self.accessors = {}
	self.attributes = GLTFAttributes()
end

function GLTFParser:getAttributes()
	return self.attributes
end

function GLTFParser:getFilename()
	return self.filename
end

--- @class RatScratch.GLTF.GLTFAccessorComponentTypeInfo
--- @field public size integer
--- @field public get string
--- @field public integer boolean
--- @field public positive integer
--- @field public negative integer
local GLTFAccessorComponentTypeInfo = {}

--- @type table<RatScratch.GLTF.AccessorComponentType, RatScratch.GLTF.GLTFAccessorComponentTypeInfo>
local COMPONENT_TYPE = {
	[GLTF.AccessorComponentType.BYTE] = { size = 1, get = "getInt8", integer = true, positive = 127, negative = 128 },
	[GLTF.AccessorComponentType.UNSIGNED_BYTE] = {
		size = 1,
		get = "getUInt8",
		integer = true,
		positive = 255,
		negative = 0,
	},
	[GLTF.AccessorComponentType.SHORT] = {
		size = 2,
		get = "getInt16",
		integer = true,
		positive = 32767,
		negative = 32768,
	},
	[GLTF.AccessorComponentType.UNSIGNED_SHORT] = {
		size = 2,
		get = "getUInt16",
		integer = true,
		positive = 65535,
		negative = 0,
	},
	[GLTF.AccessorComponentType.UNSIGNED_INT] = {
		size = 4,
		get = "getUInt32",
		integer = true,
		positive = 0,
		negative = 0,
	},
	[GLTF.AccessorComponentType.FLOAT] = { size = 4, get = "getFloat", integer = false, positive = 0, negative = 0 },
}

--- @type table<RatScratch.GLTF.AccessorElementType, integer>
local ELEMENT_COUNT = {
	SCALAR = 1,
	VEC2 = 2,
	VEC3 = 3,
	VEC4 = 4,
	MAT2 = 2,
	MAT3 = 9,
	MAT4 = 16,
}

--- @param componentType RatScratch.GLTF.AccessorComponentType
--- @return RatScratch.GLTF.GLTFAccessorComponentTypeInfo
function GLTFParser:getAccessorComponentTypeInfo(componentType)
	return COMPONENT_TYPE[componentType]
end

--- @param componentType RatScratch.GLTF.AccessorComponentType
function GLTFParser:getComponentGetter(componentType)
	local componentTypeConfig = COMPONENT_TYPE[componentType]
	assert(componentTypeConfig ~= nil, "component type not valid")

	return componentTypeConfig.get
end

--- @param elementType RatScratch.GLTF.AccessorElementType
--- @return integer
function GLTFParser:getAccessorElementTypeCount(elementType)
	return ELEMENT_COUNT[elementType] or 1
end

--- @param uri any
--- @return love.Data
--- @return unknown
function GLTFParser:getBufferDataFromDataURI(uri)
	local mimeType, encodingType, data = uri:match("^data:([^,;]*);([^,]*),(.*)$")
	assert(mimeType and encodingType and data, "encountered malformed data URI")
	assert(encodingType == "base64", "can only decode base64 data")

	local decodedData = love.data.decode("data", "base64", data)

	--- @cast decodedData love.ByteData
	return decodedData, mimeType
end

--- @param key "accessors" | "animations" | "buffers" | "bufferViews" | "cameras" | "images" | "materials" | "meshes" | "nodes" | "samplers" | "scenes"
--- @param name string
--- @param index? integer
--- @return integer?
function GLTFParser:getIndexFromName(key, name, index)
	--- @type RatScratch.GLTF.NamedObject[]
	local objects = self.root[key]
	if not objects then
		return nil
	end

	index = (index or 0) + 1
	for i = index + 1, #objects do
		local object = objects[i]
		if object.name == name then
			return i - 1
		end
	end

	return nil
end

function GLTFParser:getBufferDataFromFile(uri)
	local absolutePath = Path.resolve(self.filename, uri)
	return love.filesystem.newFileData(absolutePath)
end

--- @param uri string
--- @return boolean
function GLTFParser:isDataURI(uri)
	return not not uri:match("^data")
end

--- @param uri string
--- @return love.Data
function GLTFParser:getBufferDataFromURI(uri)
	local result

	if uri:match("^data") then
		result = self:getBufferDataFromDataURI(uri)
	else
		result = self:getBufferDataFromFile(uri)
	end

	--- @cast result love.Data
	return result
end

function GLTFParser:getBufferData(index)
	local realIndex = index + 1

	local buffer = self.root.buffers and self.root.buffers[realIndex]
	assert(buffer, "no buffer at index %d", index)

	if not buffer.uri then
		assert(self.data, "buffer without URI and no default data")
		return self.data
	end

	local data = self.buffers[realIndex]
	if not data then
		data = self:getBufferDataFromURI(buffer.uri)
		self.buffers[realIndex] = data
	end

	return data
end

function GLTFParser:getBufferViewData(index)
	local realIndex = index + 1

	local dataView = self.bufferViews[realIndex]
	if dataView then
		return dataView
	end

	local bufferView = self.root.bufferViews and self.root.bufferViews[realIndex]
	assert(bufferView, "no buffer view at index %d", index)
	assert(
		bufferView.byteStride == nil,
		"not-yet-implemented: currently only accessors can use buffer views with stride"
	)

	local data = self:getBufferData(bufferView.buffer)
	dataView = love.data.newDataView(data, bufferView.byteOffset or 0, bufferView.byteLength)

	self.bufferViews[realIndex] = dataView
	return dataView
end

local COMMON_IMAGE_MIME_TYPES_DEFAULT_FILE_EXTENSIONS = {
	["image/png"] = "png",
}

--- @param mimeType string
--- @param name? string
--- @return string
function GLTFParser:getImageFilenameFromMimeType(mimeType, name)
	local filenameExtension = COMMON_IMAGE_MIME_TYPES_DEFAULT_FILE_EXTENSIONS[mimeType]
	assert(filenameExtension, "image with mime type %s not supported", mimeType)

	return string.format("%s.%s", name or "x_necronomicon_unnamed_texture", filenameExtension)
end

--- @param data love.Data
--- @param mimeType string
--- @param name? string
--- @return love.ImageData
function GLTFParser:getImageDataFromByteData(data, mimeType, name)
	local filename = self:getImageFilenameFromMimeType(mimeType, name)
	local fileData = love.filesystem.newFileData(data, filename)

	return love.image.newImageData(fileData)
end

--- @param uri string
--- @param name? string
--- @return love.ImageData
function GLTFParser:getImageDataFromURI(uri, name)
	if self:isDataURI(uri) then
		local data, mimeType = self:getBufferDataFromDataURI(uri)
		return self:getImageDataFromByteData(data, mimeType, name)
	else
		local filename = Path.resolve(self.filename, uri)
		return love.image.newImageData(filename)
	end
end

--- @param index integer
--- @return love.ImageData
function GLTFParser:getImageData(index)
	local realIndex = index + 1

	if self.images[realIndex] then
		return self.images[realIndex]
	end

	local image = self.root.images and self.root.images[realIndex]
	assert(image, "no image at index %d", index)

	local imageData
	if image.uri then
		imageData = self:getImageDataFromURI(image.uri, image.name)
	elseif image.bufferView then
		local data = self:getBufferViewData(image.bufferView)
		local filename = self:getImageFilenameFromMimeType(image.mimeType, image.name)
		local fileData = love.filesystem.newFileData(data, filename)
		imageData = love.image.newImageData(fileData)
	end

	self.images[realIndex] = imageData
	return imageData
end

--- @param index number
--- @return RatScratch.GLTF.GLTFAccessor|RatScratch.GLTF.GLTFSparseAccessor
function GLTFParser:getAccessorParser(index)
	local realIndex = index + 1

	local accessor = self.accessors[realIndex]
	if not accessor then
		local accessorData = self:getAccessor(index)
		if accessorData.sparse then
			accessor = GLTFSparseAccessor(self, accessorData)
		else
			accessor = GLTFAccessor(self, accessorData)
		end

		self.accessors[realIndex] = accessor
	end

	return accessor
end

--- @param index number
--- @return RatScratch.GLTF.Accessor
function GLTFParser:getAccessor(index)
	local accessor = self.root.accessors and self.root.accessors[index + 1]
	assert(accessor, "no accessor at index %d", index)

	return accessor
end

function GLTFParser:getAccessorCount()
	return self.root.accessors and #self.root.accessors or 0
end

--- @param index number
--- @return RatScratch.GLTF.Animation
function GLTFParser:getAnimation(index)
	local animation = self.root.animations and self.root.animations[index + 1]
	assert(animation, "no animation at index %d", index)

	return animation
end

function GLTFParser:getAnimationCount()
	return self.root.animations and #self.root.animations or 0
end

--- @param index number
--- @return RatScratch.GLTF.Buffer
function GLTFParser:getBuffer(index)
	local buffer = self.root.buffers and self.root.buffers[index + 1]
	assert(buffer, "no buffer at index %d", index)

	return buffer
end

function GLTFParser:getBufferCount()
	return self.root.buffers and #self.root.buffers or 0
end

function GLTFParser:getBufferView(index)
	local bufferView = self.root.bufferViews and self.root.bufferViews[index + 1]
	assert(bufferView, "no bufferView at index %d", index)

	return bufferView
end

function GLTFParser:getBufferViewCount()
	return self.root.bufferViews and #self.root.bufferViews or 0
end

--- @param index number
--- @return RatScratch.GLTF.Camera
function GLTFParser:getCamera(index)
	local camera = self.root.cameras and self.root.cameras[index + 1]
	assert(camera, "no camera at index %d", index)

	return camera
end

function GLTFParser:getCameraCount()
	return self.root.cameras and #self.root.cameras or 0
end

function GLTFParser:getImage(index)
	local image = self.root.images and self.root.images[index + 1]
	assert(image, "no image at index %d", index)

	return image
end

function GLTFParser:getImageCount()
	return self.root.images and #self.root.images or 0
end

function GLTFParser:getMaterial(index)
	local material = self.root.materials and self.root.materials[index + 1]
	assert(material, "no material at index %d", index)

	return material
end

function GLTFParser:getMaterialCount()
	return self.root.materials and #self.root.materials or 0
end

--- @param index number
--- @return RatScratch.GLTF.Mesh
function GLTFParser:getMesh(index)
	local mesh = self.root.meshes and self.root.meshes[index + 1]
	assert(mesh, "no mesh at index %d", index)

	return mesh
end

--- @param index integer
--- @return integer?
function GLTFParser:getNodeParent(index)
	if not self.root.nodes then
		return nil
	end

	for nodeIndex, node in ipairs(self.root.nodes) do
		if node.children then
			for _, child in ipairs(node.children) do
				if child == index then
					return nodeIndex - 1
				end
			end
		end
	end

	return nil
end

function GLTFParser:getNode(index)
	local node = self.root.nodes and self.root.nodes[index + 1]
	assert(node, "no node at index %d", index)

	return node
end

function GLTFParser:getNodeCount()
	return self.root.nodes and #self.root.nodes or 0
end

function GLTFParser:getSampler(index)
	local sampler = self.root.samplers and self.root.samplers[index + 1]
	assert(sampler, "no sampler at index %d", index)

	return sampler
end

function GLTFParser:getSamplerCount()
	return self.root.samplers and #self.root.samplers or 0
end

function GLTFParser:getSkin(index)
	local skin = self.root.skins and self.root.skins[index + 1]
	assert(skin, "no skin at index %d", index)

	return skin
end

function GLTFParser:getSkinCount()
	return self.root.skins and #self.root.skins or 0
end

function GLTFParser:getScene(index)
	local scene = self.root.scenes and self.root.scenes[index + 1]
	assert(scene, "no scene at index %d", index)

	return scene
end

function GLTFParser:getSceneCount()
	return self.root.scenes and #self.root.scenes or 0
end

function GLTFParser:getTexture(index)
	local texture = self.root.textures and self.root.textures[index + 1]
	assert(texture, "no texture at index %d", index)

	return texture
end

function GLTFParser:getMeshCount()
	return self.root.meshes and #self.root.meshes or 0
end

function GLTFParser:getTextureCount()
	return self.root.textures and #self.root.textures or 0
end

--- @param key string | number
--- @return RatScratch.Graphics.Graphics3D.SceneDefinition
function GLTFParser:loadScene(key)
	local index
	if type(key) == "string" then
		index = self:getIndexFromName("scenes", key)
		assert(index, "no scene found with name %s", key)
	elseif type(key) == "number" then
		index = key - 1
	end

	local sceneData = self:getScene(index)
	return self:_loadScene(sceneData)
end

--- @return RatScratch.Graphics.Graphics3D.SceneDefinition[]
function GLTFParser:loadScenes()
	if not self.root.scenes then
		return {}
	end

	local scenes = {}
	for _, sceneData in ipairs(self.root.scenes) do
		table.insert(scenes, self:_loadScene(sceneData))
	end

	return scenes
end

--- @private
--- @param modelDefinitions table<integer, RatScratch.Graphics.Graphics3D.ModelDefinition>
--- @param skeletonDefinitions table<integer, RatScratch.Graphics.Graphics3D.SkeletonDefinition>
--- @param animationDefinitions table<integer, RatScratch.Graphics.Graphics3D.AnimationDefinition>
--- @param node RatScratch.GLTF.Node
--- @return RatScratch.Graphics.Graphics3D.ModelDefinition[]
function GLTFParser:_tryLoadNode(modelDefinitions, skeletonDefinitions, animationDefinitions, node)
	local models = {}

	if node.children then
		for _, child in ipairs(node.children) do
			local childNode = self:getNode(child)
			local childModels = self:_tryLoadNode(modelDefinitions, skeletonDefinitions, animationDefinitions, childNode)

			for _, childModel in ipairs(childModels) do
				table.insert(models, childModel)
			end
		end
	end

	if node.mesh then
		local meshData = self:getMesh(node.mesh)
		local skinData = node.skin and self:getSkin(node.skin)

		local model = modelDefinitions[node.mesh] or self:_loadMesh(meshData, not not skinData)

		local skeleton = node.skin and (skeletonDefinitions[node.skin] or self:_loadSkin(skinData))
		model.skeleton = model.skeleton or skeleton

		local animations = node.skin and (animationDefinitions[node.skin] or self:_loadAnimations(skeleton, skinData.skeleton))
		model.animations = model.animations or animations

		table.insert(models, model)
	end

	return models
end

--- @private
--- @param sceneData RatScratch.GLTF.Scene
--- @return RatScratch.Graphics.Graphics3D.SceneDefinition
function GLTFParser:_loadScene(sceneData)
	--- @type RatScratch.Graphics.Graphics3D.SceneDefinition
	local sceneDefinition = { models = {} }

	local modelDefinitions = {}
	local skeletonDefinitions = {}
	local animationDefinitions = {}

	for _, nodeIndex in ipairs(sceneData.nodes) do
		local models = self:_tryLoadNode(modelDefinitions, skeletonDefinitions, animationDefinitions, self:getNode(nodeIndex))

		for _, model in ipairs(models) do
			table.insert(sceneDefinition.models, model)
		end
	end

	return sceneDefinition
end

--- @private
--- @param format? RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param vertices number[][]
--- @param accessor RatScratch.GLTF.GLTFAccessor | RatScratch.GLTF.GLTFSparseAccessor
function GLTFParser:_loadVertices(format, vertices, vertexElementName, accessor)
	format = format or self.attributes:getFormat()

	local count, offset = Mesh.getAttributeCountOffset(format, vertexElementName)
	if not (count and offset) then
		return
	end

	local value = {}
	for i = 1, accessor:getElementCount() do
		accessor:read(i, value)

		local vertex = vertices[i]
		if not vertex then
			vertex = {}
			Mesh.resetVertex(format, vertex)

			table.insert(vertices, vertex)
		end

		for j = 1, math.min(count, #value) do
			vertex[(offset - 1) + j] = value[j]
		end
	end
end

local GLTF_PRIMITIVE_MODE_TO_NECRO = {
	[GLTF.MeshPrimitiveMode.LINES] = "lines",
	[GLTF.MeshPrimitiveMode.LINE_LOOP] = "linesloop",
	[GLTF.MeshPrimitiveMode.LINE_STRIP] = "linestrip",
	[GLTF.MeshPrimitiveMode.POINTS] = "points",
	[GLTF.MeshPrimitiveMode.TRIANGLES] = "triangles",
	[GLTF.MeshPrimitiveMode.TRIANGLE_FAN] = "fan",
	[GLTF.MeshPrimitiveMode.TRIANGLE_STRIP] = "strip",
}

--- @private
--- @param meshData RatScratch.GLTF.Mesh
--- @param isSkinned boolean
--- @return RatScratch.Graphics.Graphics3D.ModelDefinition
function GLTFParser:_loadMesh(meshData, isSkinned)
	--- @type RatScratch.Graphics.Graphics3D.ModelDefinition
	local modelDefinition = { meshes = {} }
	local value = {}

	for _, primitiveData in ipairs(meshData.primitives) do
		local indices
		if primitiveData.indices then
			indices = {}

			local indicesAccessor = self:getAccessorParser(primitiveData.indices)
			for i = 1, indicesAccessor:getElementCount() do
				indicesAccessor:read(i, value)
				table.insert(indices, value[1])
			end
		end

		--- @type RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
		local format = {}

		for _, attribute in ipairs(self.attributes:getFormat()) do
			local attributeName = self.attributes:getAttributeFromVertexElement(attribute.name)
			if primitiveData.attributes[attributeName] then
				table.insert(format, {
					location = attribute.location,
					name = attribute.name,
					format = attribute.format
				})
			end
		end

		local vertices = {}
		for attributeName, accessorIndex in pairs(primitiveData.attributes) do
			if self.attributes:hasAttribute(attributeName) then
				local attributeAccessor = self:getAccessorParser(accessorIndex)
				self:_loadVertices(
					format,
					vertices,
					self.attributes:getVertexElementFromAttribute(attributeName),
					attributeAccessor
				)
			end
		end

		local material
		if primitiveData.material then
		material = self:_loadMaterial(primitiveData.material)
		end

		local indexMode = GLTF_PRIMITIVE_MODE_TO_NECRO[primitiveData.mode]

		local outputBuffers, outputIndices, outputFormat
		if isSkinned then
			outputFormat = Mesh.SKINNED_MESH_FORMAT
			outputBuffers, outputIndices = Mesh.marshal(
				{
					Mesh.CONSTANT_BUFFER_DEFINITION,
					Mesh.TRANSFORM_INPUT_BUFFER_DEFINITION,
					Mesh.TRANSFORM_OUTPUT_BUFFER_DEFINITION,
				},
				format,
				vertices,
				indices,
				indexMode
			)
		else
			outputFormat = Mesh.STATIC_MESH_FORMAT
			outputBuffers, outputIndices = Mesh.marshal(
				{
					Mesh.STATIC_BUFFER_DEFINITION
				},
				format,
				vertices,
				indices,
				indexMode
			)
		end

		--- @type RatScratch.Graphics.Graphics3D.MeshDefinition
		local meshDefinition = {
			format = outputFormat,
			buffers = outputBuffers,
			vertices = vertices,
			indices = outputIndices,
			material = material
		}

		table.insert(modelDefinition.meshes, meshDefinition)
	end

	return modelDefinition
end

--- @private
--- @param skinData RatScratch.GLTF.Skin
--- @return RatScratch.Graphics.Graphics3D.SkeletonDefinition
function GLTFParser:_loadSkin(skinData)
	local matrices = {}
	if skinData.inverseBindMatrices then
		local accessor = self:getAccessorParser(skinData.inverseBindMatrices)
		assert(
			#skinData.joints <= accessor:getElementCount(),
			"not enough inverse bind matrices; expected at least %d, got %d",
			#skinData.joints,
			accessor:getElementCount()
		)

		local matrixValue = {}
		for i = 1, #skinData.joints do
			accessor:read(i, matrixValue)

			local transform = love.math.newTransform()
			transform:setMatrix("column", unpack(matrixValue))

			table.insert(matrices, transform)
		end
	else
		for i = 1, #skinData.joints do
			table.insert(matrices, love.math.newTransform())
		end
	end

	--- @type RatScratch.Graphics.Graphics3D.BoneDefinition[]
	local bones = {}

	local joints = {}
	local hasRoot = false
	for i, nodeIndex in ipairs(skinData.joints) do
		hasRoot = hasRoot or nodeIndex == skinData.skeleton
		table.insert(joints, { boneIndex = i, nodeIndex = nodeIndex })
	end

	for i, nodeIndex in pairs(skinData.joints) do
		local node = self:getNode(nodeIndex)

		local translation = node.translation and { unpack(node.translation) } or { Vector3.ZERO:get() }
		local scale = node.scale and { unpack(node.scale) } or { Vector3.ONE:get() }
		local rotation = node.rotation and { unpack(node.rotation) } or { Quaternion.IDENTITY:get() }

		local transform = love.math.newTransform()
		if node.matrix then
			transform:setMatrix("column", unpack(node.matrix))
		end

		local parentID = self:getNodeParent(nodeIndex)
		local isInSkeleton = parentID == skinData.skeleton
		for _, jointIndex in ipairs(skinData.joints) do
			if jointIndex == parentID then
				isInSkeleton = true
				break
			end
		end

		if not isInSkeleton then
			parentID = nil
		end

		--- @type RatScratch.Graphics.Graphics3D.BoneDefinition
		local bone = {
			name = node.name,
			index = i,
			id = nodeIndex,
			parentID = parentID,
			inverseBindPoseTransform = matrices[i] or love.math.newTransform(),
			transform = transform,
			translation = translation,
			rotation = rotation,
			scale = scale,
		}

		table.insert(bones, bone)
	end

	local rootNode = self:getNode(skinData.skeleton or skinData.joints[1])

	return {
		name = rootNode.name,
		bones = bones,
	}
end

--- @private
--- @param index integer
--- @return table<integer, true>
function GLTFParser:_getAnimationNodesMap(index)
	local animationNodesMap = self.animationsNodesMap[index]
	if animationNodesMap then
		return animationNodesMap
	end

	local animationData = self:getAnimation(index - 1)
	animationNodesMap = {}

	for _, channelData in ipairs(animationData.channels) do
		animationNodesMap[channelData.target.node] = true
	end

	self.animationsNodesMap[index] = animationNodesMap
	return animationNodesMap
end

--- @private
--- @param skeletonNodeMap table<integer, true>
--- @param animationNodesMap table<integer, true>
--- @param root integer
--- @return boolean
function GLTFParser:_isAnimationNodeMapMatch(skeletonNodeMap, animationNodesMap, root)
	for id in pairs(animationNodesMap) do
		if not (skeletonNodeMap[id] or id == root) then
			return false
		end
	end

	return true
end

--- @private
--- @param skeleton RatScratch.Graphics.Graphics3D.SkeletonDefinition
--- @param root integer
--- @return RatScratch.Graphics.Graphics3D.AnimationDefinition[]?
function GLTFParser:_loadAnimations(skeleton, root)
	if not self.root.animations then
		return nil
	end

	local skeletonNodeMap = { [root] = true }
	for _, bone in ipairs(skeleton.bones) do
		skeletonNodeMap[bone.id] = true
	end

	--- @type RatScratch.Graphics.Graphics3D.Animation[]
	local animations = {}
	for index, animationData in ipairs(self.root.animations) do
		local animationNodesMap = self:_getAnimationNodesMap(index)

		if self:_isAnimationNodeMapMatch(skeletonNodeMap, animationNodesMap, root) then
			local channels = self:_loadAnimation(animationData)
			table.insert(animations, { name = animationData.name or "", channels = channels })
		end
	end

	return animations
end

--- @type table<RatScratch.GLTF.AnimationChannelSamplerInterpolation, RatScratch.Graphics.Graphics3D.InterpolatorType>
local GLTF_INTERPOLATION_MODE_TO_NECRO = {
	STEP = "step",
	LINEAR = "linear",
	CUBICSPLINE = "cubicSpline",
}

--- @type table<RatScratch.GLTF.AnimationChannelTargetPath, RatScratch.Graphics.Graphics3D.KeyFramePropertyType>
local GLTF_INTERPOLATION_PROPERTY_TYPES_TO_NECRO = {
	position = "position",
	rotation = "rotation",
	scale = "scale",
}

--- @private
--- @param animationData RatScratch.GLTF.Animation
--- @param channelData RatScratch.GLTF.AnimationChannel
--- @return RatScratch.Graphics.Graphics3D.KeyFramesDefinition
function GLTFParser:_loadAnimationChannel(animationData, channelData)
	local samplerData = animationData.samplers[channelData.sampler + 1]

	--- @type RatScratch.Graphics.Graphics3D.KeyFramesDefinition
	local keyFrames = {
		interpolation = GLTF_INTERPOLATION_MODE_TO_NECRO[samplerData.interpolation or "LINEAR"],
		property = GLTF_INTERPOLATION_PROPERTY_TYPES_TO_NECRO[channelData.target.path],
		frames = {},
	}

	local timeValuesAccessor = self:getAccessorParser(samplerData.input)
	local animationValuesAccessor = self:getAccessorParser(samplerData.output)

	local timeValue = {}
	for i = 1, timeValuesAccessor:getElementCount() do
		timeValuesAccessor:read(i, timeValue)

		local inTangentValue, outTangentValue
		local value = {}
		if samplerData.interpolation == "CUBICSPLINE" then
			inTangentValue = {}
			outTangentValue = {}

			local j = (i - 1) * 3 + 1

			animationValuesAccessor:read(j, inTangentValue)
			animationValuesAccessor:read(j + 1, value)
			animationValuesAccessor:read(j + 2, outTangentValue)
		else
			animationValuesAccessor:read(i, value)
		end

		--- @type RatScratch.Graphics.Graphics3D.KeyFrameDefinition
		local keyFrameDefinition = {
			time = timeValue[1],
			inTangent = inTangentValue,
			value = value,
			outTangent = outTangentValue,
		}

		table.insert(keyFrames.frames, keyFrameDefinition)
	end

	return keyFrames
end

--- @private
--- @param animationData RatScratch.GLTF.Animation
--- @return RatScratch.Graphics.Graphics3D.AnimationChannelDefinition[]
function GLTFParser:_loadAnimation(animationData)
	--- @type table<integer, RatScratch.Graphics.Graphics3D.AnimationChannelDefinition>
	local channelsByBone = {}

	--- @type RatScratch.Graphics.Graphics3D.AnimationChannelDefinition[]
	local channels = {}

	for _, channelData in ipairs(animationData.channels) do
		local propertyType = GLTF_INTERPOLATION_PROPERTY_TYPES_TO_NECRO[channelData.target.path]
		local boneID = channelData.target.node
		if propertyType then
			local channelDefinition = channelsByBone[boneID]
			if not channelDefinition then
				channelDefinition = {
					boneID = boneID,
					properties = {},
				}

				channelsByBone[boneID] = channelDefinition
				table.insert(channels, channelDefinition)
			end

			local properties = self:_loadAnimationChannel(animationData, channelData)
			table.insert(channelDefinition.properties, properties)
		end
	end

	return channels
end

local GLTF_MIN_FILTER_TO_NECRONOMICON = {
	[GLTF.SamplerMinFilter.LINEAR] = { "linear", false },
	[GLTF.SamplerMinFilter.LINEAR_MIPMAP_LINEAR] = { "linear", "linear" },
	[GLTF.SamplerMinFilter.LINEAR_MIPMAP_NEAREST] = { "linear", "nearest" },
	[GLTF.SamplerMinFilter.NEAREST] = { "nearest", false },
	[GLTF.SamplerMinFilter.NEAREST_MIPMAP_LINEAR] = { "nearest", "linear" },
	[GLTF.SamplerMinFilter.NEAREST_MIPMAP_NEAREST] = { "nearest", "nearest" },
}

local GLTF_MAG_FILTER_TO_NECRONOMICON = {
	[GLTF.SamplerMagFilter.LINEAR] = "linear",
	[GLTF.SamplerMagFilter.NEAREST] = "nearest",
}

local GLTF_WRAP_MODE_TO_NECRONOMICON = {
	[GLTF.SamplerWrap.CLAMP_TO_EDGE] = "clamp",
	[GLTF.SamplerWrap.MIRRORED_REPEAT] = "mirroredrepeat",
	[GLTF.SamplerWrap.REPEAT] = "repeat",
}

--- @private
--- @return RatScratch.Graphics.Graphics3D.MaterialDefinition
function GLTFParser:_makeDefaultImageData()
	return {
		texture = DEFAULT_WHITE_IMAGE_DATA,
	}
end

--- @private
--- @param index integer
--- @return RatScratch.Graphics.Graphics3D.MaterialDefinition?
function GLTFParser:_loadMaterial(index)
	local material = self:getMaterial(index)

	local color = material.pbrMetallicRoughness and material.pbrMetallicRoughness.baseColorFactor
	color = color and { unpack(color) }

	local textureInfo = material.pbrMetallicRoughness and material.pbrMetallicRoughness.baseColorTexture
	if not textureInfo then
		if color then
			return { color = color }
		end

		return nil
	end

	local texture = self:getTexture(textureInfo.index)
	local sampler = texture.sampler and self:getSampler(texture.sampler)
	local image = self:getImageData(texture.source)

	local horizontalWrapMode = GLTF_WRAP_MODE_TO_NECRONOMICON[sampler and sampler.wrapS or GLTF.SamplerWrap.REPEAT]
	local verticalWrapMode = GLTF_WRAP_MODE_TO_NECRONOMICON[sampler and sampler.wrapT or GLTF.SamplerWrap.REPEAT]
	local magFilter = GLTF_MAG_FILTER_TO_NECRONOMICON[sampler and sampler.magFilter or GLTF.SamplerMagFilter.LINEAR] or "linear"
	local minFilter, mipmapMinFilter =
		unpack(GLTF_MIN_FILTER_TO_NECRONOMICON[sampler and sampler.minFilter or GLTF.SamplerMinFilter.LINEAR])
	--- @cast minFilter string

	return {
		texture = image,
		minFilter = minFilter or "linear",
		magFilter = magFilter,
		mipmapFilter = mipmapMinFilter or nil,
		mipmaps = not not mipmapMinFilter,
		horizontalWrapMode = horizontalWrapMode,
		verticalWrapMode = verticalWrapMode,
		color = color or { 1, 1, 1, 1 },
	}
end

return GLTFParser
