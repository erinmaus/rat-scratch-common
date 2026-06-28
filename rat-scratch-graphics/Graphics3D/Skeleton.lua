local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object

--- @class RatScratch.Graphics.Graphics3D.Skeleton : RatScratch.Common.BaseObject
--- @overload fun(bones: RatScratch.Graphics.Graphics3D.Bone[]): RatScratch.Graphics.Graphics3D.Skeleton
--- @field private bones RatScratch.Graphics.Graphics3D.Bone[]
--- @field private bonesByName table<string, RatScratch.Graphics.Graphics3D.Bone>
--- @field private bonesByID table<integer, RatScratch.Graphics.Graphics3D.Bone>
--- @field private boneToIndex table<RatScratch.Graphics.Graphics3D.Bone, integer>
--- @field private boneChildren table<RatScratch.Graphics.Graphics3D.Bone, RatScratch.Graphics.Graphics3D.Bone[]>
local Skeleton = Object()

--- @param bones RatScratch.Graphics.Graphics3D.Bone[]
--- @return RatScratch.Graphics.Graphics3D.Bone[], table<integer, RatScratch.Graphics.Graphics3D.Bone>, table<string, RatScratch.Graphics.Graphics3D.Bone>, table<RatScratch.Graphics.Graphics3D.Bone, integer>, table<RatScratch.Graphics.Graphics3D.Bone, RatScratch.Graphics.Graphics3D.Bone[]>
function Skeleton.validateBones(bones)
	local outputBones = {}
	local outputBonesByID = {}
	local outputBonesByName = {}
	local outputBoneToIndex = {}
	local outputBoneChildren = {}

	for i, bone in ipairs(bones) do
		local name = bone:getName()
		if name ~= "" then
			assert(
				not outputBonesByName[name],
				"bone with name already exists: %s",
				name
			)
			outputBonesByName[name] = bone
		end

		assert(
			not outputBonesByID[bone:getID()],
			"bone with ID already exists: %d",
			bone:getID()
		)
		outputBonesByID[bone:getID()] = bone

		table.insert(outputBones, bone)

		local parent = bone:getParent()
		local children = parent and (outputBoneChildren[parent] or {})

		if parent and children then
			table.insert(children, bone)
			outputBoneChildren[parent] = children
		end

		outputBoneToIndex[bone] = i
	end

	return outputBones,
		outputBonesByID,
		outputBonesByName,
		outputBoneToIndex,
		outputBoneChildren
end

--- @param bones RatScratch.Graphics.Graphics3D.Bone[]
function Skeleton:new(bones)
	local outputBones, outputBonesByID, outputBonesByName, outputBoneToIndex, outputBoneChildren =
		Skeleton.validateBones(bones)

	self.bones = outputBones
	self.bonesByID = outputBonesByID
	self.bonesByName = outputBonesByName
	self.boneToIndex = outputBoneToIndex
	self.boneChildren = outputBoneChildren
end

--- @param key number | string
--- @return RatScratch.Graphics.Graphics3D.Bone
function Skeleton:getBone(key)
	if type(key) == "number" then
		assert(self.bones[key] ~= nil, "no bone at index: %d", key)
		return self.bones[key]
	elseif type(key) == "string" then
		assert(self.bonesByName[key] ~= nil, "no bone with given name: %s", key)
		return self.bonesByName[key]
	end

	error('expected "number" or "string" for parameter "key"')
end

--- @param id integer
function Skeleton:hasBoneByID(id)
	return self.bonesByID[id] ~= nil
end

--- @param id integer
--- @return RatScratch.Graphics.Graphics3D.Bone
function Skeleton:getBoneByID(id)
	local bone = self.bonesByID[id]
	assert(bone, "no bone with ID: %d", id)

	return bone
end

--- @param bone number | string | RatScratch.Graphics.Graphics3D.Bone ID, name, or bone itself
--- @return integer
function Skeleton:getBoneIndex(bone)
	if type(bone) == "number" then
		bone = self:getBoneByID(bone)
	elseif type(bone) == "string" then
		bone = self:getBone(bone)
	end

	return self.boneToIndex[bone]
end

--- @return RatScratch.Graphics.Graphics3D.Bone
function Skeleton:getRootBone()
	return self.bones[1]
end

function Skeleton:getBoneCount()
	return #self.bones
end

--- @param bone number | string | RatScratch.Graphics.Graphics3D.Bone
--- @return number
function Skeleton:getBoneChildrenCount(bone)
	if type(bone) == "number" or type(bone) == "string" then
		bone = self:getBone(bone)
	end

	local children = self.boneChildren[bone]
	return children and #children or 0
end

--- @param bone number | string | RatScratch.Graphics.Graphics3D.Bone
--- @return RatScratch.Graphics.Graphics3D.Bone
function Skeleton:getBoneChild(bone, index)
	if type(bone) == "number" or type(bone) == "string" then
		bone = self:getBone(bone)
	end

	local children = self.boneChildren[bone]
	assert(
		children,
		"bone has no children for bone at index: %d",
		self:getBoneIndex(bone)
	)
	assert(children[index], "bone has no child at index: %d", index)

	return children[index]
end

return Skeleton
