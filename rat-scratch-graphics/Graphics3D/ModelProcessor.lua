local PATH = ...
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Module = require("lib.rat-scratch-module")
local ShaderPreprocessor = require("rat-scratch-graphics.ShaderPreprocessor")
local Transform          = require("rat-scratch-math").Transform

--- @class RatScratch.Graphics.Graphics3D.ModelProcessor : RatScratch.Common.BaseObject
--- @overload fun(model: RatScratch.Graphics.Graphics3D.SkinnedModel): RatScratch.Graphics.Graphics3D.ModelProcessor
--- @field private model RatScratch.Graphics.Graphics3D.SkinnedModel
--- @field private bonesData number[][]
--- @field private bonesBuffer love.graphics.GraphicsBuffer
local ModelProcessor = Object()

ModelProcessor.BONE_FORMAT = {
	{ location = 0, name = "bone", format = "floatmat4x4" }
}

--- @private
--- @type love.Shader | false
ModelProcessor._SKIN_SHADER = false

--- @return love.Shader
function ModelProcessor.getSkinShader()
	local shader = ModelProcessor._SKIN_SHADER
	if not shader then
		local modulePath = Module.getSelfPath()
		local shaderRootPath = ("%s/Shaders"):format(modulePath)
		shader = ShaderPreprocessor.newComputeShader("@/SkinnedModel/Skin.compute.glsl", { rootPath = shaderRootPath })

		ModelProcessor._SKIN_SHADER = shader
	end

	return shader
end

--- @param model RatScratch.Graphics.Graphics3D.SkinnedModel
function ModelProcessor:new(model)
	self.model = model
	self:_initBones()
end

--- @private
function ModelProcessor:_initBones()
	self.bonesData = {}

	local skeleton = self.model:getSkeleton()
	for i = 1, skeleton:getBoneCount() do
		table.insert(self.bonesData, {
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1,
		})
	end

	self.bonesBuffer = love.graphics.newBuffer(ModelProcessor.BONE_FORMAT, #self.bonesData, { shaderstorage = true })
end

do
	local boneTransform = love.math.newTransform()

	--- @param animator RatScratch.Graphics.Graphics3D.Animator
	function ModelProcessor:skin(animator)
		local shader = ModelProcessor.getSkinShader()

		local skeleton = self.model:getSkeleton()
		for i = 1, skeleton:getBoneCount() do
			local bone = self.model:getSkeleton():getBone(i)
			local index = bone:getIndex()

			if index >= 1 then
				local boneData = self.bonesData[index]
				animator:getBoneTransform(bone, boneTransform)

				Transform.transposeTransform(boneTransform)

				boneData[1], boneData[2], boneData[3], boneData[4],
				boneData[5], boneData[6], boneData[7], boneData[8],
				boneData[9], boneData[10], boneData[11], boneData[12],
				boneData[13], boneData[14], boneData[15], boneData[16] = boneTransform:getMatrix()
			end
		end

		self.bonesBuffer:setArrayData(self.bonesData)

		for i = 1, self.model:getMeshCount() do
			local mesh = self.model:getMesh(i)

			local inputBuffer = mesh:getBufferByRole("compute_input")
			local outputBuffer = mesh:getBufferByRole("compute_output")
			if inputBuffer and outputBuffer then
				local count = inputBuffer:getElementCount()
				shader:send("rat_SkinnedMeshInputVerticesBuffer", inputBuffer)
				shader:send("rat_SkinnedMeshOutputVerticesBuffer", outputBuffer)
				shader:send("rat_BoneMatrixBuffer", self.bonesBuffer)
				shader:send("rat_VertexCount", count)

				local threadGroupSize = shader:getLocalThreadgroupSize()

				love.graphics.dispatchThreadgroups(shader, math.max(math.ceil(count / threadGroupSize), 1), 1, 1)
			end
		end
	end
end

return ModelProcessor
