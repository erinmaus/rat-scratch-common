local PATH = ...
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Transform = require("rat-scratch-math").Transform
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local GLTF = require("rat-scratch-gltf.GLTF.Types")
local GLTFAttributes = require("rat-scratch-gltf.GLTF.Attributes")
local GLTFParser = require("rat-scratch-gltf.GLTF.Parser")
local RatScratchModule = require("lib.rat-scratch-module")
local Types = require("rat-scratch-gltf.GLTF.Types")
local ffi = require("ffi")

--- @class RatScratch.GLTF.GLTFBuilder : RatScratch.Common.BaseObject
--- @overload fun(root?: RatScratch.GLTF.GLTF, data?: love.Data): RatScratch.GLTF.GLTFBuilder
--- @field private root RatScratch.GLTF.GLTF
--- @field private data love.ByteData[]
--- @field private workingBufferViews table<integer, RatScratch.GLTF.WorkingBufferView>
--- @field private attributes RatScratch.GLTF.GLTFAttributes
local GLTFBuilder = Object()

GLTFBuilder.INVERSE_BIND_POSE_FORMAT = {
	{ location = 0, name = "inverseBindPose", format = "floatmat4x4" },
}

GLTFBuilder.FLOAT_FORMAT = {
	{ location = 0, name = "value", format = "float" },
}

GLTFBuilder.INDEX_FORMAT = {
	{ location = 0, name = "index", format = "uint32" },
}

--- @param root? RatScratch.GLTF.GLTF
--- @param data any
function GLTFBuilder:new(root, data)
	self.root = Table.deepClone(root or GLTFBuilder.getDefaultRoot())
	if root then
		self.root.asset = {
			generator = GLTFBuilder.getGeneratorString(),
			copyright = self.root.asset.copyright or "",
			version = GLTF.GLTF_VERSION,
			minVersion = GLTF.GLTF_VERSION,
			extension = self.root.asset.extensions,

			extras = {
				RAT_asset_original = {
					asset = {
						generator = self.root.asset.generator,
						copyright = self.root.asset.copyright,
						version = self.root.asset.version,
						minVersion = self.root.asset.minVersion,
						extras = self.root.asset.extras,
					},
				},
			},
		}
	end

	self.data = {}
	if data then
		table.insert(self.data, love.data.newByteData(data))
	end

	self.attributes = GLTFAttributes.makeDefault()

	self.workingBufferViews = {}
end

--- @param accessor RatScratch.GLTF.Accessor
--- @return integer, RatScratch.GLTF.Accessor
function GLTFBuilder:addAccessor(accessor)
	local accessors = self.root.accessors
	if not accessors then
		accessors = {}
		self.root.accessors = accessors
	end

	local result = Table.deepClone(accessor)
	table.insert(accessors, result)
	return #accessors - 1, result
end

--- @param workingBufferView RatScratch.GLTF.WorkingBufferView
--- @return integer, RatScratch.GLTF.BufferView
function GLTFBuilder:addWorkingBufferView(workingBufferView)
	local bufferViewIndex = self:addBufferView({
		buffer = 0,
		byteLength = workingBufferView.dataLength
			or workingBufferView.data:getSize(),
		byteOffset = workingBufferView.dataOffset,
		byteStride = workingBufferView.dataStride,
	})

	self.workingBufferViews[bufferViewIndex] =
		Table.deepClone(workingBufferView)
	return bufferViewIndex, self:getBufferView(bufferViewIndex)
end

--- @param workingAccessor RatScratch.GLTF.WorkingAccessor
--- @return integer, RatScratch.GLTF.Accessor
function GLTFBuilder:addWorkingAccessor(workingAccessor)
	local bufferViewIndex =
		self:addWorkingBufferView(workingAccessor.bufferView)

	---@type RatScratch.GLTF.Accessor
	local accessor = {
		bufferView = bufferViewIndex,
		byteOffset = 0,
		componentType = workingAccessor.componentType,
		count = workingAccessor.count,
		type = workingAccessor.type,
		min = workingAccessor.min,
		max = workingAccessor.max,
	}

	local index = self:addAccessor(accessor)
	return index, self:getAccessor(index)
end

--- @param animation RatScratch.GLTF.Animation
--- @return integer, RatScratch.GLTF.Animation
function GLTFBuilder:addAnimation(animation)
	local animations = self.root.animations
	if not animations then
		animations = {}
		self.root.animations = animations
	end

	local result = Table.deepClone(animation)
	table.insert(animations, result)
	return #animations - 1, result
end

--- @param buffer RatScratch.GLTF.Buffer
--- @return integer, RatScratch.GLTF.Buffer
function GLTFBuilder:addBuffer(buffer)
	local buffers = self.root.buffers
	if not buffers then
		buffers = {}
		self.root.buffers = buffers
	end

	local result = Table.deepClone(buffer)
	table.insert(buffers, result)
	return #buffers - 1, result
end

--- @param bufferView  RatScratch.GLTF.BufferView
--- @return integer, RatScratch.GLTF.BufferView
function GLTFBuilder:addBufferView(bufferView)
	local bufferViews = self.root.bufferViews
	if not bufferViews then
		bufferViews = {}
		self.root.bufferViews = bufferViews
	end

	local result = Table.deepClone(bufferView)
	table.insert(self.root.bufferViews, result)
	return #self.root.bufferViews - 1, result
end

--- @param camera RatScratch.GLTF.Camera
--- @return integer, RatScratch.GLTF.Camera
function GLTFBuilder:addCamera(camera)
	local cameras = self.root.cameras
	if not cameras then
		cameras = {}
		self.root.cameras = cameras
	end

	local result = Table.deepClone(camera)
	table.insert(cameras, result)
	return #cameras - 1, result
end

--- @param image RatScratch.GLTF.Image
--- @return integer, RatScratch.GLTF.Image
function GLTFBuilder:addImage(image)
	local images = self.root.images
	if not images then
		images = {}
		self.root.images = images
	end

	local result = Table.deepClone(image)
	table.insert(images, result)
	return #images - 1, result
end

--- @param material RatScratch.GLTF.Material
--- @return integer, RatScratch.GLTF.Material
function GLTFBuilder:addMaterial(material)
	local materials = self.root.materials
	if not materials then
		materials = {}
		self.root.materials = materials
	end

	local result = Table.deepClone(material)
	table.insert(materials, result)
	return #materials - 1, result
end

--- @param mesh RatScratch.GLTF.Mesh
--- @return integer, RatScratch.GLTF.Mesh
function GLTFBuilder:addMesh(mesh)
	local meshes = self.root.meshes
	if not meshes then
		meshes = {}
		self.root.meshes = meshes
	end

	local result = Table.deepClone(mesh)
	table.insert(meshes, result)
	return #meshes - 1, result
end

--- @param node RatScratch.GLTF.Node
--- @return integer, RatScratch.GLTF.Node
function GLTFBuilder:addNode(node)
	local nodes = self.root.nodes
	if not nodes then
		nodes = {}
		self.root.nodes = nodes
	end

	local result = Table.deepClone(node)
	table.insert(nodes, result)
	return #nodes - 1, result
end

--- @param sampler RatScratch.GLTF.Sampler
--- @return integer, RatScratch.GLTF.Sampler
function GLTFBuilder:addSampler(sampler)
	local samplers = self.root.samplers
	if not samplers then
		samplers = {}
		self.root.samplers = samplers
	end

	local result = Table.deepClone(sampler)
	table.insert(samplers, result)
	return #samplers - 1, result
end

--- @param skin RatScratch.GLTF.Skin
--- @return integer, RatScratch.GLTF.Skin
function GLTFBuilder:addSkin(skin)
	local skins = self.root.skins
	if not skins then
		skins = {}
		self.root.skins = skins
	end

	local result = Table.deepClone(skin)
	table.insert(skins, result)
	return #skins - 1, result
end

--- @param scene RatScratch.GLTF.Scene
--- @return integer, RatScratch.GLTF.Scene
function GLTFBuilder:addScene(scene)
	local scenes = self.root.scenes
	if not scenes then
		scenes = {}
		self.root.scenes = scenes
	end

	local result = Table.deepClone(scene)
	table.insert(scenes, result)
	return #scenes - 1, result
end

--- @param texture RatScratch.GLTF.Texture
--- @return integer, RatScratch.GLTF.Texture
function GLTFBuilder:addTexture(texture)
	local textures = self.root.textures
	if not textures then
		textures = {}
		self.root.textures = textures
	end

	local result = Table.deepClone(texture)
	table.insert(textures, result)
	return #textures - 1, result
end

--- @param index number
--- @return RatScratch.GLTF.Accessor
function GLTFBuilder:getAccessor(index)
	local accessor = self.root.accessors and self.root.accessors[index + 1]
	assert(accessor, "no accessor at index %d", index)

	return accessor
end

function GLTFBuilder:getAccessorCount()
	return self.root.accessors and #self.root.accessors or 0
end

--- @param index number
--- @return RatScratch.GLTF.Animation
function GLTFBuilder:getAnimation(index)
	local animation = self.root.animations and self.root.animations[index + 1]
	assert(animation, "no animation at index %d", index)

	return animation
end

function GLTFBuilder:getAnimationCount()
	return self.root.animations and #self.root.animations or 0
end

--- @param index number
--- @return RatScratch.GLTF.Buffer
function GLTFBuilder:getBuffer(index)
	local buffer = self.root.buffers and self.root.buffers[index + 1]
	assert(buffer, "no buffer at index %d", index)

	return buffer
end

function GLTFBuilder:getBufferCount()
	return self.root.buffers and #self.root.buffers or 0
end

function GLTFBuilder:getBufferView(index)
	local bufferView = self.root.bufferViews
		and self.root.bufferViews[index + 1]
	assert(bufferView, "no bufferView at index %d", index)

	return bufferView
end

function GLTFBuilder:getBufferViewCount()
	return self.root.bufferViews and #self.root.bufferViews or 0
end

--- @param index number
--- @return RatScratch.GLTF.Camera
function GLTFBuilder:getCamera(index)
	local camera = self.root.cameras and self.root.cameras[index + 1]
	assert(camera, "no camera at index %d", index)

	return camera
end

function GLTFBuilder:getCameraCount()
	return self.root.cameras and #self.root.cameras or 0
end

function GLTFBuilder:getImage(index)
	local image = self.root.images and self.root.images[index + 1]
	assert(image, "no image at index %d", index)

	return image
end

function GLTFBuilder:getImageCount()
	return self.root.images and #self.root.images or 0
end

function GLTFBuilder:getMaterial(index)
	local material = self.root.materials and self.root.materials[index + 1]
	assert(material, "no material at index %d", index)

	return material
end

function GLTFBuilder:getMaterialCount()
	return self.root.materials and #self.root.materials or 0
end

--- @param index number
--- @return RatScratch.GLTF.Mesh
function GLTFBuilder:getMesh(index)
	local mesh = self.root.meshes and self.root.meshes[index + 1]
	assert(mesh, "no mesh at index %d", index)

	return mesh
end

function GLTFBuilder:getNode(index)
	local node = self.root.nodes and self.root.nodes[index + 1]
	assert(node, "no node at index %d", index)

	return node
end

function GLTFBuilder:getNodeCount()
	return self.root.nodes and #self.root.nodes or 0
end

function GLTFBuilder:getSampler(index)
	local sampler = self.root.samplers and self.root.samplers[index + 1]
	assert(sampler, "no sampler at index %d", index)

	return sampler
end

function GLTFBuilder:getSamplerCount()
	return self.root.samplers and #self.root.samplers or 0
end

function GLTFBuilder:getSkin(index)
	local skin = self.root.skins and self.root.skins[index + 1]
	assert(skin, "no skin at index %d", index)

	return skin
end

function GLTFBuilder:getSkinCount()
	return self.root.skins and #self.root.skins or 0
end

function GLTFBuilder:getScene(index)
	local scene = self.root.scenes and self.root.scenes[index + 1]
	assert(scene, "no scene at index %d", index)

	return scene
end

function GLTFBuilder:getSceneCount()
	return self.root.scenes and #self.root.scenes or 0
end

function GLTFBuilder:getTexture(index)
	local texture = self.root.textures and self.root.textures[index + 1]
	assert(texture, "no texture at index %d", index)

	return texture
end

function GLTFBuilder:getMeshCount()
	return self.root.meshes and #self.root.meshes or 0
end

function GLTFBuilder:getTextureCount()
	return self.root.textures and #self.root.textures or 0
end

--- @param index integer
--- @return integer?
function GLTFBuilder:getNodeParent(index)
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

function GLTFBuilder:getRoot()
	return self.root
end

--- @param value string
function GLTFBuilder:setCopyright(value)
	self.root.asset.copyright = value or ""
end

--- @param index integer
function GLTFBuilder:setDefaultScene(index)
	if self.root.scenes then
		if index >= 0 and index < #self.root.scenes then
			self.root.scene = index
		end
	else
		self.root.scene = nil
	end
end

--- @param data love.Data
--- @return love.ByteData
function GLTFBuilder:addData(data)
	local result = love.data.newByteData(data)
	table.insert(self.data, result)

	return result
end

--- @param format RatScratch.Graphics.Graphics3D.BufferFormat
--- @param tableData number[]
function GLTFBuilder:addDataFromFlatTable(format, tableData)
	local componentCount = format:getComponentCount()
	local count = #tableData / componentCount

	local result = love.data.newByteData(count * format:getStride())
	BufferFormat.copyFromFlatTableToByteData(
		format,
		1,
		0,
		count,
		tableData,
		result
	)

	table.insert(self.data, result)
	return result
end

function GLTFBuilder.getGeneratorString()
	local version = RatScratchModule.getSelfVersion(PATH)
	return ("RatScratch.GLTF.GLTFBuilder (rat-scratch-gltf %s)"):format(version)
end

--- @return RatScratch.GLTF.GLTF
function GLTFBuilder.getDefaultRoot()
	return {
		asset = {
			generator = GLTFBuilder.getGeneratorString(),
			copyright = "",
			version = GLTF.GLTF_VERSION,
			minVersion = GLTF.GLTF_VERSION,
		},
	}
end

--- @private
--- @param object RatScratch.GLTF.Object
--- @param index integer
--- @param definition RatScratch.Graphics.Graphics3D.Definition
function GLTFBuilder:_trySerialize(object, index, definition)
	--- @type RatScratch.GLTF.Extra.RAT_extras_serialize?
	local serialize = definition.extras
		and definition.extras.RAT_extras_serialize
	if serialize then
		if serialize.userdata then
			serialize.serialize(
				serialize.userdata,
				self,
				object,
				index,
				definition
			)
		else
			serialize.serialize(self, object, index, definition)
		end
	end
end

--- @private
--- @param skeletonDefinition RatScratch.Graphics.Graphics3D.SkeletonDefinition
--- @return integer, table<integer, integer>
function GLTFBuilder:_addSkeletonDefinition(skeletonDefinition)
	--- @type RatScratch.GLTF.Skin
	local skin = { joints = {} }

	local inverseBindPoseTransformsBufferData = {}
	local boneIDToNodeIndex = {}
	for i, boneDefinition in ipairs(skeletonDefinition.bones) do
		local nodeIndex, node = self:addNode({ name = boneDefinition.name })
		self:_trySerialize(node, nodeIndex, boneDefinition)

		boneIDToNodeIndex[boneDefinition.id] = nodeIndex
	end

	for i, boneDefinition in ipairs(skeletonDefinition.bones) do
		local nodeIndex = boneIDToNodeIndex[boneDefinition.id]
		local node = self:getNode(nodeIndex)

		if boneDefinition.parentID then
			local parentNodeIndex = boneIDToNodeIndex[boneDefinition.parentID]
			if parentNodeIndex then
				local parentNode = self:getNode(parentNodeIndex)

				if not parentNode.children then
					parentNode.children = {}
				end

				table.insert(parentNode.children, nodeIndex)
			end
		end

		if node.matrix then
			node.matrix = { unpack(node.matrix) }
		else
			node.translation = { unpack(boneDefinition.translation) }
			node.rotation = { unpack(boneDefinition.rotation) }
			node.scale = { unpack(boneDefinition.scale) }
		end

		table.insert(skin.joints, nodeIndex)

		local inverseBindPoseTransform = Transform.transposeTransform(
			boneDefinition.inverseBindPoseTransform,
			love.math.newTransform()
		)

		Table.append(
			inverseBindPoseTransformsBufferData,
			inverseBindPoseTransform:getMatrix()
		)

		skin.skeleton = skin.skeleton or nodeIndex
	end

	local inverseBindPoseFormat =
		BufferFormat.get(GLTFBuilder.INVERSE_BIND_POSE_FORMAT)
	local inverseBindPoseData = self:addDataFromFlatTable(
		inverseBindPoseFormat,
		inverseBindPoseTransformsBufferData
	)

	skin.inverseBindMatrices = self:addWorkingAccessor({
		bufferView = {
			data = inverseBindPoseData,
		},

		componentType = Types.AccessorComponentType.FLOAT,
		count = #skeletonDefinition.bones,
		type = "MAT4",
	})

	local skinIndex, skinObject = self:addSkin(skin)
	self:_trySerialize(skinObject, skinIndex, skeletonDefinition)

	return skinIndex, boneIDToNodeIndex
end

--- @type table<RatScratch.Graphics.Graphics3D.KeyFramePropertyType, RatScratch.GLTF.AnimationChannelTargetPath>
local RAT_SCRATCH_PROPERTY_TYPE_TO_GLTF_PATH = {
	position = "translation",
	rotation = "rotation",
	scale = "scale",
}

--- @type table<RatScratch.Graphics.Graphics3D.KeyFramePropertyType, RatScratch.GLTF.AccessorElementType>
local RAT_SCRATCH_PROPERTY_TYPE_TO_GLTF_ACCESSOR_TYPE = {
	position = "VEC3",
	rotation = "VEC4",
	scale = "VEC3",
}

--- @type table<RatScratch.Graphics.Graphics3D.InterpolatorType, RatScratch.GLTF.AnimationChannelSamplerInterpolation>
local RAT_SCRATCH_INTERPOLATION_MODE_TO_GLTF_INTERPOLATION_MODE = {
	step = "STEP",
	linear = "LINEAR",
	cubicSpline = "CUBICSPLINE",
}

--- @private
--- @param animationDefinition RatScratch.Graphics.Graphics3D.AnimationDefinition
--- @param bones table<integer, integer>
function GLTFBuilder:_addAnimationDefinition(animationDefinition, bones)
	local animationIndex, animation = self:addAnimation({
		name = animationDefinition.name,
		channels = {},
		samplers = {},
	})

	for _, channelDefinition in ipairs(animationDefinition.channels) do
		for _, propertyDefinition in ipairs(channelDefinition.properties) do
			--- @type RatScratch.GLTF.AnimationChannel
			local channel = {
				sampler = #animation.samplers,

				target = {
					node = bones[channelDefinition.boneID],
					path = RAT_SCRATCH_PROPERTY_TYPE_TO_GLTF_PATH[propertyDefinition.property],
				},
			}

			--- @type number[], number[]
			local inputData, outputData = {}, {}
			for _, frameDefinition in ipairs(propertyDefinition.frames) do
				table.insert(inputData, frameDefinition.time)

				if propertyDefinition.interpolation == "cubicSpline" then
					Table.append(
						outputData,
						Table.unpack(frameDefinition.inTangent)
					)
					Table.append(
						outputData,
						Table.unpack(frameDefinition.value)
					)
					Table.append(
						outputData,
						Table.unpack(frameDefinition.outTangent)
					)
				else
					Table.append(
						outputData,
						Table.unpack(frameDefinition.value)
					)
				end
			end

			local inputAccessorIndex = self:addWorkingAccessor({
				bufferView = {
					data = self:addDataFromFlatTable(
						BufferFormat.get(GLTFBuilder.FLOAT_FORMAT),
						inputData
					),
				},

				componentType = Types.AccessorComponentType.FLOAT,
				count = #propertyDefinition.frames,
				type = "SCALAR",
			})

			local outputCount
			if propertyDefinition.interpolation == "cubicSpline" then
				outputCount = #propertyDefinition.frames * 3
			else
				outputCount = #propertyDefinition.frames
			end

			local outputAccessorIndex = self:addWorkingAccessor({
				bufferView = {
					data = self:addDataFromFlatTable(
						BufferFormat.get(GLTFBuilder.FLOAT_FORMAT),
						outputData
					),
				},

				componentType = Types.AccessorComponentType.FLOAT,
				count = outputCount,
				type = RAT_SCRATCH_PROPERTY_TYPE_TO_GLTF_ACCESSOR_TYPE[propertyDefinition.property],
			})

			--- @type RatScratch.GLTF.AnimationChannelSampler
			local sampler = {
				input = inputAccessorIndex,
				output = outputAccessorIndex,
				interpolation = RAT_SCRATCH_INTERPOLATION_MODE_TO_GLTF_INTERPOLATION_MODE[propertyDefinition.interpolation],
			}

			table.insert(animation.channels, channel)
			table.insert(animation.samplers, sampler)
		end
	end

	self:_trySerialize(animation, animationIndex, animationDefinition)

	return animationIndex
end

--- @private
--- @param animationDefinitions RatScratch.Graphics.Graphics3D.AnimationDefinition[]
--- @param bones table<integer, integer>
function GLTFBuilder:_addAnimationDefinitions(animationDefinitions, bones)
	for _, animationDefinition in ipairs(animationDefinitions) do
		self:_addAnimationDefinition(animationDefinition, bones)
	end
end

local RAT_SCRATCH_ATTRIBUTE_SCALAR_TO_GLTF_ACCESSOR_COMPONENT_TYPE = {
	float = Types.AccessorComponentType.FLOAT,
	uint32 = Types.AccessorComponentType.UNSIGNED_INT,
	int32 = Types.AccessorComponentType.UNSIGNED_INT,
	uint16 = Types.AccessorComponentType.UNSIGNED_SHORT,
	int16 = Types.AccessorComponentType.SHORT,
}

local COMPONENT_COUNT_TO_ACCESSOR_TYPE = {
	"SCALAR",
	"VEC2",
	"VEC3",
	"VEC4",
}

local function _marshalVertexFormat(format)
	local scalar = BufferFormat.getFormatScalar(format)
	local count = BufferFormat.getFormatComponentCount(format)
	if scalar == "uint32" then
		scalar = "uint16"
	elseif scalar == "int32" then
		scalar = "int16"
	end

	return BufferFormat.getFormatFromScalarComponentCount(scalar, count)
end

--- @private
--- @param materialDefinitionTexture RatScratch.Graphics.Graphics3D.MaterialDefinitionTexture
--- @return integer?
function GLTFBuilder:_addMaterialDefinitionTexture(materialDefinitionTexture)
	if
		not (materialDefinitionTexture and materialDefinitionTexture.texture)
	then
		return nil
	end

	local imageData =
		self:addData(materialDefinitionTexture.texture:encode("png"))

	local bufferViewIndex = self:addWorkingBufferView({
		data = imageData,
		dataOffset = 0,
		dataLength = imageData:getSize(),
	})

	local imageSource = self:addImage({
		bufferView = bufferViewIndex,
		mimeType = "image/png",
	})

	local textureIndex = self:addTexture({
		source = imageSource,
	})

	return textureIndex
end

--- @private
--- @param materialDefinition RatScratch.Graphics.Graphics3D.MaterialDefinition
function GLTFBuilder:_addMaterialDefinition(materialDefinition)
	local baseColorTextureIndex =
		self:_addMaterialDefinitionTexture(materialDefinition.texture)
	local normalTextureIndex =
		self:_addMaterialDefinitionTexture(materialDefinition.normalTexture)
	local occlusionTextureIndex =
		self:_addMaterialDefinitionTexture(materialDefinition.occlusionTexture)
	local metallicRoughnessTextureIndex = self:_addMaterialDefinitionTexture(
		materialDefinition.metalRoughnessTexture
	)
	local emissiveTextureIndex =
		self:_addMaterialDefinitionTexture(materialDefinition.emissiveTexture)

	local materialIndex, material = self:addMaterial({
		pbrMetallicRoughness = (
			baseColorTextureIndex or metallicRoughnessTextureIndex
		)
			and {
				baseColorTexture = baseColorTextureIndex and {
					index = baseColorTextureIndex,
				},

				metallicRoughnessTexture = metallicRoughnessTextureIndex and {
					index = metallicRoughnessTextureIndex,
				},

				metallicFactor = materialDefinition.metalRoughnessTexture
					and materialDefinition.metalRoughnessTexture.metalFactor,
				roughnessFactor = materialDefinition.metalRoughnessTexture
					and materialDefinition.metalRoughnessTexture.roughnessFactor,
				baseColorFactor = materialDefinition.texture
					and materialDefinition.texture.albedoFactor
					and {
						unpack(materialDefinition.texture.albedoFactor),
					},
			},
		normalTexture = normalTextureIndex and {
			index = normalTextureIndex,
			scale = materialDefinition.normalTexture
				and materialDefinition.normalTexture.normalScale,
		},
		occlusionTexture = occlusionTextureIndex and {
			index = occlusionTextureIndex,
			scale = materialDefinition.occlusionTexture
				and materialDefinition.occlusionTexture.occlusionStrength,
		},
		emissiveTexture = emissiveTextureIndex and {
			index = emissiveTextureIndex,
		},
		emissiveFactor = materialDefinition.emissiveTexture
			and materialDefinition.emissiveTexture.emissiveFactor
			and { unpack(materialDefinition.emissiveTexture.emissiveFactor) },
	})

	self:_trySerialize(material, materialIndex, materialDefinition)

	return materialIndex
end

--- @private
--- @param modelDefinition RatScratch.Graphics.Graphics3D.ModelDefinition
--- @param materials table<integer, integer>
function GLTFBuilder:_addModelDefinition(modelDefinition, materials)
	local meshIndex, mesh =
		self:addMesh({ name = modelDefinition.name, primitives = {} })

	for _, meshDefinition in ipairs(modelDefinition.meshes) do
		--- @type RatScratch.GLTF.MeshPrimitive
		local primitive = {
			attributes = {},
		}

		local inputBufferFormat = BufferFormat(meshDefinition.format)
		for _, attribute in ipairs(inputBufferFormat:getFormat()) do
			local count, offset =
				inputBufferFormat:getCountOffset(attribute.name)
			local i, j = offset, offset + count - 1

			local outputBufferFormat = BufferFormat({
				{
					location = attribute.location,
					name = attribute.name,
					format = _marshalVertexFormat(attribute.format),
				},
			}, true)

			local min, max
			if attribute.name == "VertexPosition" then
				min, max = {}, {}

				for k, vertex in ipairs(meshDefinition.vertices) do
					for c = 1, count do
						local o = c - 1
						local v = vertex[i + o]

						min[c] = math.min(min[c] or v, v)
						max[c] = math.max(max[c] or v, v)
					end
				end
			end

			local bufferData = {}
			for k, vertex in ipairs(meshDefinition.vertices) do
				local o = (k - 1) * outputBufferFormat:getComponentCount() + 1

				Table.copy(
					bufferData,
					o,
					o + count - 1,
					Table.unpack(vertex, i, j)
				)
			end

			local attributeData =
				self:addDataFromFlatTable(outputBufferFormat, bufferData)
			local attributeAccessorIndex = self:addWorkingAccessor({
				bufferView = {
					data = attributeData,
				},
				componentType = RAT_SCRATCH_ATTRIBUTE_SCALAR_TO_GLTF_ACCESSOR_COMPONENT_TYPE[outputBufferFormat:getScalarType(
					attribute.name
				)],
				count = #meshDefinition.vertices,
				type = COMPONENT_COUNT_TO_ACCESSOR_TYPE[outputBufferFormat:getCountOffset(
					attribute.name
				)],
				min = min,
				max = max,
			})

			local indexData = self:addDataFromFlatTable(
				BufferFormat.get(GLTFBuilder.INDEX_FORMAT),
				meshDefinition.indices
			)
			local indexAccessorIndex = self:addWorkingAccessor({
				bufferView = {
					data = indexData,
				},
				componentType = Types.AccessorComponentType.UNSIGNED_INT,
				count = #meshDefinition.indices,
				type = "SCALAR",
			})

			local gltfAttribute =
				self.attributes:getAttributeFromVertexElement(attribute.name)
			primitive.attributes[gltfAttribute] = attributeAccessorIndex
			primitive.indices = indexAccessorIndex
		end

		if meshDefinition.material and meshDefinition.material.texture then
			if
				meshDefinition.material.id
				and materials[meshDefinition.material.id]
			then
				primitive.material = materials[meshDefinition.material.id]
			else
				local materialIndex =
					self:_addMaterialDefinition(meshDefinition.material)
				if meshDefinition.material.id then
					materials[meshDefinition.material.id] = materialIndex
				end

				primitive.material = materialIndex
			end
		end

		table.insert(mesh.primitives, primitive)
	end

	return meshIndex
end

--- @param sceneDefinition RatScratch.Graphics.Graphics3D.SceneDefinition
--- @return integer
function GLTFBuilder:fromSceneDefinition(sceneDefinition)
	local materials = {}

	local nodes = {}
	for _, modelDefinition in ipairs(sceneDefinition.models) do
		--- @type integer?
		local skin
		if modelDefinition.skeleton then
			local bones
			skin, bones = self:_addSkeletonDefinition(modelDefinition.skeleton)

			if modelDefinition.animations then
				self:_addAnimationDefinitions(modelDefinition.animations, bones)
			end
		end

		local mesh = self:_addModelDefinition(modelDefinition, materials)

		local matrix
		if modelDefinition.transform then
			local transform = Transform.transposeTransform(
				modelDefinition.transform,
				love.math.newTransform()
			)
			matrix = { transform:getMatrix() }
		end

		local nodeIndex, node = self:addNode({
			mesh = mesh,
			skin = skin,
			matrix = matrix,
		})

		self:_trySerialize(node, nodeIndex, modelDefinition)
		table.insert(nodes, nodeIndex)
	end

	local sceneIndex, scene = self:addScene({
		name = sceneDefinition.name,
		nodes = nodes,
	})

	self:_trySerialize(scene, sceneIndex, sceneDefinition)
	return sceneIndex
end

--- @param filename string
--- @return RatScratch.GLTF.GLTFParser
function GLTFBuilder:build(filename)
	local data
	do
		local dataOffset = {}

		local totalDataSize = 0
		for _, subdata in ipairs(self.data) do
			totalDataSize = totalDataSize + subdata:getSize()
		end

		data = love.data.newByteData(totalDataSize)

		local offset = 0
		for _, subdata in ipairs(self.data) do
			ffi.copy(
				ffi.cast("uint8_t *", data:getFFIPointer()) + offset,
				subdata:getFFIPointer(),
				subdata:getSize()
			)

			dataOffset[subdata] = offset

			offset = offset + subdata:getSize()
		end

		for bufferViewIndex, workingBufferView in pairs(self.workingBufferViews) do
			local bufferView = self:getBufferView(bufferViewIndex)
			local bufferViewOffset = dataOffset[workingBufferView.data]
			bufferView.byteOffset = bufferViewOffset
		end
		Table.clear(self.workingBufferViews)

		Table.clear(self.data)
		self.data[1] = data
	end

	local root = Table.deepClone(self.root)
	root.buffers = {
		{
			byteLength = data:getSize(),
		},
	}

	return GLTFParser(filename, root, data)
end

return GLTFBuilder
