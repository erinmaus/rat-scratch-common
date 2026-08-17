local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local Transform = require("rat-scratch-math").Transform
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Atlas = require("rat-scratch-graphics").Atlas.Atlas
local Common = require("rat-scratch-math.Common")
local Mesh = require("rat-scratch-graphics.Graphics3D.Mesh")
local Table = require("rat-scratch-common.Table")
local ffi = require("ffi")
local GLTFAttributes = require("rat-scratch-gltf").Attributes
local GLTFBuilder = require("rat-scratch-gltf").Builder
local GLTFTypes = require("rat-scratch-gltf").Types
local GLTFParser = require("rat-scratch-gltf").Parser
local ImageDataAtlasHandle =
	require("rat-scratch-graphics").Atlas.ImageDataAtlasHandle

--- @class RatScratch.Pipeline.MohoScene.WorkingNode : RatScratch.GLTF.Node
--- @field public workingChildren? RatScratch.Pipeline.MohoScene.WorkingNode[]

--- @class RatScratch.Pipeline.MohoScene : RatScratch.Common.BaseObject
--- @overload fun(parser: RatScratch.GLTF.GLTFParser, sceneIndex: integer): RatScratch.Pipeline.MohoScene
--- @field private parser RatScratch.GLTF.GLTFParser
--- @field private sceneIndex integer
--- @field private rootNode RatScratch.Pipeline.MohoScene.WorkingNode
--- @field private skin RatScratch.GLTF.Skin
--- @field private nodeIndexToBoneIndex table<integer, integer>
--- @field private inverseBindPoseTransforms love.Transform[]
--- @field private inverseBindPoseTransformsData love.ByteData
--- @field private atlas RatScratch.Graphics.Atlas
--- @field private atlasImageData? love.ImageData
--- @field private materialsByMaterialIndex table<integer, RatScratch.Graphics.Atlas.ImageDataAtlasHandle>
--- @field private materials RatScratch.Graphics.Atlas.ImageDataAtlasHandle[]
--- @field private mesh number[][]
--- @field private indices number[]
--- @field private attributes RatScratch.GLTF.GLTFAttributes
--- @field private meshData table<string, love.ByteData>
--- @field private indexData? love.ByteData
--- @field private result RatScratch.GLTF.GLTFParser
local MohoScene = Object()
MohoScene.INCREMENT = 512

MohoScene.MESH_FORMAT_INSTANCE = BufferFormat({
	{ name = "VertexPosition", format = "floatvec3" },
	{ name = "VertexTexCoord", format = "floatvec2" },
	{ name = "VertexColor", format = "floatvec4" },
	{ name = "VertexNormal", format = "floatvec3" },
	{ name = "VertexBoneIndex", format = "uint16vec4" },
	{ name = "VertexBoneWeight", format = "floatvec4" },
})

MohoScene.MESH_FORMAT = MohoScene.MESH_FORMAT_INSTANCE:getFormat()

MohoScene.INVERSE_BIND_POSE_FORMAT = {
	{ location = 0, name = "inverseBindPose", format = "floatmat4x4" },
}

--- comment
--- @param parser RatScratch.GLTF.GLTFParser
--- @param sceneIndex integer
function MohoScene:new(parser, sceneIndex)
	self.parser = parser
	self.sceneIndex = sceneIndex

	self.rootNode = { name = "root", workingChildren = {} }
	self.childNodes = {}
	self.skin = { joints = {} }
	self.nodeIndexToBoneIndex = {}
	self.inverseBindPoseTransforms = {}
	self.nodes = {}
	self.boneNodeIndices = {}
	self.nodeToSkin = {}

	self.width = 1024
	self.height = 1024
	self.atlas = Atlas(self.width, self.height, 1)
	self.materialsByMaterialIndex = {}
	self.materials = {}
	self.mesh = {}
	self.indices = {}
	self.attributes = GLTFAttributes.fromFormat(MohoScene.MESH_FORMAT)
	self.meshData = {}

	self.result = self:_generate()
end

--- @return RatScratch.GLTF.GLTFParser
function MohoScene:build()
	if not self.result then
		self.result = self:_generate()
	end

	return self.result
end

--- @private
function MohoScene:_getAtlasImageData()
	if not self.atlasImageData and self.atlas:getTexture() then
		self.atlasImageData =
			love.graphics.readbackTexture(self.atlas:getTexture(), 1)
	end

	return self.atlasImageData
end

--- @param nodeIndex integer
--- @return integer?
function MohoScene:_getParentBoneIndex(nodeIndex)
	--- @type integer?
	local currentIndex = nodeIndex
	while currentIndex and not self.boneNodeIndices[currentIndex] do
		currentIndex = self.parser:getNodeParent(currentIndex)
	end

	return currentIndex
end

--- @private
--- @param nodeIndex integer
--- @return integer?
function MohoScene:_getRemappedBoneIndex(nodeIndex)
	local boneIndex = self.nodeIndexToBoneIndex[nodeIndex]
	if boneIndex then
		return boneIndex
	end

	for i, n in ipairs(self.skin.joints) do
		if n == nodeIndex then
			boneIndex = i - 1
			break
		end
	end

	if boneIndex then
		self.nodeIndexToBoneIndex[nodeIndex] = boneIndex
	end

	return boneIndex
end

--- @private
--- @param material integer
--- @param imageData love.ImageData
--- @return RatScratch.Graphics.Atlas.ImageDataAtlasHandle
function MohoScene:_addMaterial(material, imageData)
	if self.materialsByMaterialIndex[material] then
		return self.materialsByMaterialIndex[material]
	end

	local handle = ImageDataAtlasHandle(imageData)
	while not self.atlas:add(handle) do
		self.atlas:repack()

		if not self.atlas:add(handle) then
			if self.width >= self.height then
				self.height = self.height + MohoScene.INCREMENT
			else
				self.width = self.width + MohoScene.INCREMENT
			end

			self.atlas = Atlas(self.width, self.height, 1)
			for _, material in pairs(self.materials) do
				if not self.atlas:add(material) then
					self.atlas:repack()
					local success = self.atlas:add(material)

					assert(success, "could not rebuild atlas")
				end
			end
		end
	end

	table.insert(self.materials, handle)
	self.materialsByMaterialIndex[material] = handle

	if self.atlasImageData then
		self.atlasImageData:release()
		self.atlasImageData = nil
	end

	return handle
end

--- @private
--- @param nodeIndex integer
function MohoScene:_addMeshMaterials(nodeIndex)
	local node = self.parser:getNode(nodeIndex)
	if not node.mesh then
		return
	end

	local mesh = self.parser:getMesh(node.mesh)
	for i = 1, #mesh.primitives do
		local submesh = mesh.primitives[i]

		--- @type RatScratch.Graphics.Atlas.ImageDataAtlasHandle
		local material = self.materialsByMaterialIndex[submesh.material]
		if not material and submesh.material then
			local submeshMaterial = self.parser:getMaterial(submesh.material)

			local baseColorTexture = submeshMaterial.pbrMetallicRoughness
				and submeshMaterial.pbrMetallicRoughness.baseColorTexture
			local texture = baseColorTexture
				and self.parser:getTexture(baseColorTexture.index)
			local imageData = texture
				and texture.source
				and self.parser:getImageData(texture.source)

			if imageData then
				material = self:_addMaterial(submesh.material, imageData)
			end
		end
	end
end

--- @private
--- @param nodeIndex integer
--- @param skinIndex integer?
--- @param submeshIndex integer
--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
function MohoScene:_appendMesh(
	nodeIndex,
	skinIndex,
	submeshIndex,
	meshDefinition
)
	local node = self.parser:getNode(nodeIndex)
	local mesh = self.parser:getMesh(node.mesh)
	local submesh = mesh.primitives[submeshIndex]

	local bufferFormat = BufferFormat.get(meshDefinition.format)

	--- @type RatScratch.Graphics.Atlas.ImageDataAtlasHandle
	local material = self.materialsByMaterialIndex[submesh.material]
	local skin = skinIndex and self.parser:getSkin(skinIndex)

	local vertexOffset = #self.mesh
	for i = 1, #meshDefinition.vertices do
		local inputVertex = meshDefinition.vertices[i]
		local outputVertex = {}
		BufferFormat.resetValue(self.MESH_FORMAT_INSTANCE, outputVertex)

		for _, attribute in ipairs(self.MESH_FORMAT) do
			local outputCount, outputOffset =
				self.MESH_FORMAT_INSTANCE:getCountOffset(attribute.name)
			local outputI, outputJ =
				outputOffset, outputOffset + outputCount - 1

			if bufferFormat:hasAttribute(attribute.name) then
				local inputCount, inputOffset =
					bufferFormat:getCountOffset(attribute.name)
				local inputI, inputJ = inputOffset, inputOffset + inputCount - 1

				if attribute.name == "VertexTexCoord" then
					local s1, t1, p, q = bufferFormat:getExpandedValues(
						attribute.name,
						Table.unpack(inputVertex, inputI, inputJ)
					)
					local s2, t2 =
						self.atlas:wrapTextureCoordinates(material, s1, t1)

					Table.copy(
						outputVertex,
						outputI,
						outputJ,
						s2 or s1,
						t2 or t1,
						p,
						q
					)
				elseif attribute.name == "VertexBoneIndex" then
					assert(skin, "mesh does not have skin")

					local b1, b2, b3, b4 =
						Table.unpack(inputVertex, inputI, inputJ)
					local m1 =
						self:_getRemappedBoneIndex(skin.joints[(b1 or 0) + 1])
					local m2 =
						self:_getRemappedBoneIndex(skin.joints[(b2 or 0) + 1])
					local m3 =
						self:_getRemappedBoneIndex(skin.joints[(b3 or 0) + 1])
					local m4 =
						self:_getRemappedBoneIndex(skin.joints[(b4 or 0) + 1])

					Table.copy(outputVertex, outputI, outputJ, m1, m2, m3, m4)
				else
					Table.copy(
						outputVertex,
						outputI,
						outputJ,
						Table.unpack(inputVertex, inputI, inputJ)
					)
				end
			else
				if attribute.name == "VertexBoneIndex" then
					local boneIndex = self:_getRemappedBoneIndex(nodeIndex)
					Table.copy(
						outputVertex,
						outputI,
						outputJ,
						boneIndex,
						0,
						0,
						0
					)
				elseif attribute.name == "VertexBoneWeight" then
					Table.copy(outputVertex, outputI, outputJ, 1, 0, 0, 0)
				end
			end
		end

		table.insert(self.mesh, outputVertex)
	end

	for i = 1, #meshDefinition.indices do
		local index = meshDefinition.indices[i] + vertexOffset
		table.insert(self.indices, index)
	end
end

--- @private
--- @param nodeIndex integer
function MohoScene:_buildMesh(nodeIndex)
	local node = self.parser:getNode(nodeIndex)

	local meshDefinitions = node.mesh and self.parser:loadMesh(node.mesh)
	if not meshDefinitions then
		return
	end

	for i, meshDefinition in ipairs(meshDefinitions) do
		self:_appendMesh(nodeIndex, node.skin, i, meshDefinition)
	end
end

--- @private
--- @param nodeIndex integer
function MohoScene:_buildMaterials(nodeIndex)
	local node = self.parser:getNode(nodeIndex)
	self:_addMeshMaterials(nodeIndex)

	if node.children then
		for _, childIndex in ipairs(node.children) do
			self:_buildMaterials(childIndex)
		end
	end
end

--- @private
--- @param nodeIndex integer
function MohoScene:_buildModel(nodeIndex)
	local node = self.parser:getNode(nodeIndex)
	self:_buildMesh(nodeIndex)

	if node.children then
		for _, childIndex in ipairs(node.children) do
			self:_buildModel(childIndex)
		end
	end
end

--- @private

--- @param index integer
--- @return RatScratch.Pipeline.MohoScene.WorkingNode
function MohoScene:_buildBone(index)
	local node = self.parser:getNode(index)

	local childNode = {
		matrix = node.matrix and { unpack(node.matrix) },
		translation = node.translation and { unpack(node.translation) },
		rotation = node.rotation and { unpack(node.rotation) },
		scale = node.scale and { unpack(node.scale) },
	}

	table.insert(self.skin.joints, index)

	local transform
	if self.boneNodeIndices[index] then
		transform = self:_getInverseBindPose(index)
	else
		transform = self:_getBindPose(index):inverse()
	end
	table.insert(self.inverseBindPoseTransforms, transform)

	if node.children then
		childNode.workingChildren = {}

		for _, child in ipairs(node.children) do
			local otherChildNode = self:_buildBone(child)
			table.insert(childNode.workingChildren, otherChildNode)
		end
	end

	return childNode
end

--- @param nodeIndex integer
--- @return love.Transform
function MohoScene:_getBindPose(nodeIndex)
	local transform = love.math.newTransform()

	--- @type integer?
	local currentIndex = nodeIndex
	while currentIndex and not self.boneNodeIndices[currentIndex] do
		local node = self.parser:getNode(currentIndex or nodeIndex)

		local parentTransform = love.math.newTransform()
		if node.matrix then
			parentTransform:setMatrix("column", unpack(node.matrix))
		elseif node.translation or node.scale or node.rotation then
			local translation = node.translation
					and Vector3(unpack(node.translation))
				or Vector3(0)
			local rotation = node.rotation and Quaternion(unpack(node.rotation))
				or Quaternion()
			local scale = node.scale and Vector3(unpack(node.scale))
				or Vector3(1)

			Transform.compose(translation, rotation, scale, parentTransform)
		end
		transform = parentTransform * transform

		currentIndex = self.parser:getNodeParent(currentIndex)
	end

	local inverseBindPoseTransform = self:_getInverseBindPose(nodeIndex)
	return inverseBindPoseTransform:inverse() * transform
end

--- @param nodeIndex integer
--- @return love.Transform
function MohoScene:_getInverseBindPose(nodeIndex)
	local skinIndex

	--- @type integer?
	local currentIndex = nodeIndex
	while currentIndex and not self.boneNodeIndices[currentIndex] do
		currentIndex = self.parser:getNodeParent(currentIndex)
	end

	if not currentIndex then
		return love.math.newTransform()
	end

	local skinIndex = self.boneNodeIndices[currentIndex]
	local skin = self.parser:getSkin(skinIndex)

	local inverseBonePoseIndex
	for i, boneIndex in ipairs(skin.joints) do
		if boneIndex == currentIndex then
			inverseBonePoseIndex = i
			break
		end
	end

	if not inverseBonePoseIndex then
		return love.math.newTransform()
	end

	local matrix = {}
	do
		local accessor = self.parser:getAccessorParser(skin.inverseBindMatrices)
		accessor:read(inverseBonePoseIndex, matrix)
	end

	local transform = love.math.newTransform()
	transform:setMatrix("column", matrix)

	return transform
end

--- @private
function MohoScene:_generateInverseBindPose()
	local bufferData = {}
	for i, inverseBindPoseTransform in ipairs(self.inverseBindPoseTransforms) do
		-- local nodeIndex = self.skin.joints[i]

		-- local transform
		-- for j = 1, self.parser:getSkinCount() do
		-- 	local skin = self.parser:getSkin(j - 1)
		-- 	for k = 1, #skin.joints do
		-- 		if skin.joints[k] == nodeIndex then
		-- 			local accessor = self.parser:getAccessorParser(skin.inverseBindMatrices)
		-- 			local matrix = {}
		-- 			accessor:read(k, matrix)

		-- 			transform = love.math.newTransform()
		-- 			transform:setMatrix("column", unpack(matrix))
		-- 		end
		-- 	end
		-- end

		-- if not transform then
		-- 	transform = inverseBindPoseTransform:inverse()
		-- end

		local transform =
			Transform.transposeTransform(inverseBindPoseTransform:clone())
		Table.append(bufferData, transform:getMatrix())
	end

	self.inverseBindPoseData = love.data.newByteData(
		ffi.sizeof("float") * 16 * #self.inverseBindPoseTransforms
	)

	BufferFormat.copyFromFlatTableToByteData(
		MohoScene.INVERSE_BIND_POSE_FORMAT,
		1,
		0,
		#self.inverseBindPoseTransforms,
		bufferData,
		self.inverseBindPoseData
	)
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param parentNode RatScratch.GLTF.Node
--- @param workingNodeChildren RatScratch.Pipeline.MohoScene.WorkingNode[]
function MohoScene:_materializeChildren(
	builder,
	parentNode,
	workingNodeChildren
)
	local nodes = {}

	for _, workingChildNode in ipairs(workingNodeChildren) do
		local nodeIndex, node = builder:addNode({
			matrix = workingChildNode.matrix,
			translation = workingChildNode.translation,
			rotation = workingChildNode.rotation,
			scale = workingChildNode.scale,
			children = workingChildNode.children and {},
		})

		table.insert(nodes, node)
	end

	for i, node in ipairs(nodes) do
		local workingNodeChildren = workingNodeChildren[i]
		if workingNodeChildren.workingChildren then
			self:_materializeChildren(builder, node, workingNodeChildren)
		end
	end
end

--- @private
function MohoScene:_rebuildGLTF()
	local builder = GLTFBuilder(self.parser:getJSON(), self.parser:getData())
	self.skin.inverseBindMatrices = builder:addWorkingAccessor({
		bufferView = {
			data = builder:addData(self.inverseBindPoseData),
		},
		componentType = GLTFTypes.AccessorComponentType.FLOAT,
		count = #self.inverseBindPoseTransforms,
		type = "MAT4",
	})

	self.rootNode.skin = builder:addSkin(self.skin)
	self.rootNode.mesh = builder:addMesh({ primitives = {} })
	local rootNodeIndex, rootNode = builder:addNode({
		name = "root",
		skin = self.rootNode.skin,
		mesh = self.rootNode.mesh,
		children = self.rootNode.workingChildren and {},
	})
	self:_materializeChildren(builder, rootNode, self.rootNode.workingChildren)

	local sceneIndex = builder:addScene({ nodes = { rootNodeIndex } })
	builder:setDefaultScene(sceneIndex)
	return builder:build(self.parser:getFilename())
end

--- @private
--- @param parser RatScratch.GLTF.GLTFParser
function MohoScene:_cleanGLTF(parser)
	local scene = parser:loadScene()
	scene.models = {
		{
			meshes = {
				{
					buffers = {},
					vertices = self.mesh,
					indices = self.indices,
					format = MohoScene.MESH_FORMAT,
					material = {
						texture = self:_getAtlasImageData(),
						color = { 1, 1, 1, 1 },
					},
				},
			},

			animations = scene.models[1].animations,
			skeleton = scene.models[1].skeleton,
		},
	}

	local builder = GLTFBuilder()
	builder:fromSceneDefinition(scene)

	return builder:build(parser:getFilename())
end

function MohoScene:_sortIndices()
	local triangles = {}

	local triangleCount = #self.indices / 3
	for i = 1, triangleCount do
		table.insert(triangles, i)
	end
	local _, offset = self.MESH_FORMAT_INSTANCE:getCountOffset("VertexPosition")
	local z = offset + 3 - 1

	Table.sort(triangles, 1, #triangles, function(a, b)
		local ai = self.indices[(a - 1) * 3 + 1]
		local bi = self.indices[(b - 1) * 3 + 1]

		local za = self.mesh[ai + 1][z]
		local zb = self.mesh[bi + 1][z]

		return za - zb
	end)

	local indices = Table.new(#self.indices, 0)
	for i = 1, #triangles do
		local o = (triangles[i] - 1) * 3

		for j = 1, 3 do
			local k = j + o
			table.insert(indices, self.indices[k])
		end
	end

	self.indices = indices
end

--- @private
function MohoScene:_build()
	local scene = self.parser:getScene(self.sceneIndex)

	for i = 1, self.parser:getSkinCount() do
		local skinIndex = i - 1
		local skin = self.parser:getSkin(skinIndex)

		for j = 1, #skin.joints do
			local nodeIndex = skin.joints[j]
			self.boneNodeIndices[nodeIndex] = skinIndex
		end
	end

	for _, nodeIndex in ipairs(scene.nodes) do
		local childNode = self:_buildBone(nodeIndex)
		table.insert(self.rootNode.workingChildren, childNode)
	end

	for _, nodeIndex in ipairs(scene.nodes) do
		self:_buildMaterials(nodeIndex)
	end

	for _, nodeIndex in ipairs(scene.nodes) do
		self:_buildModel(nodeIndex)
	end

	self:_generateInverseBindPose()
	self:_sortIndices()
end

--- @private
function MohoScene:_generate()
	self:_build()

	local parser = self:_rebuildGLTF()
	return self:_cleanGLTF(parser)
end

return MohoScene
