local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Graphics.Graphics3D.BoneInstance : RatScratch.Common.BaseObject
--- @overload fun(bone: RatScratch.Graphics.Graphics3D.Bone): RatScratch.Graphics.Graphics3D.BoneInstance
--- @field private bone RatScratch.Graphics.Graphics3D.Bone
--- @field private translation RatScratch.Math.Vector3
--- @field private rotation RatScratch.Math.Quaternion
--- @field private scale RatScratch.Math.Vector3
local BoneInstance = Object()

function BoneInstance:new(bone)
	self.bone = bone
	self.translation = Vector3()
	self.rotation = Quaternion()
	self.scale = Vector3(1)
end

function BoneInstance:from(bone)
	self.bone = bone
end

function BoneInstance:getBone()
	return self.bone
end

function BoneInstance:getID()
	return self.bone:getID()
end

function BoneInstance:getTranslation()
	return self.translation
end

--- @param value RatScratch.Math.Vector3
function BoneInstance:setTranslation(value)
	self.translation:from(value:get())
end

function BoneInstance:getRotation()
	return self.rotation
end

--- @param value RatScratch.Math.Quaternion
function BoneInstance:setRotation(value)
	self.rotation:from(value:get())
end

function BoneInstance:getScale()
	return self.scale
end

--- @param value RatScratch.Math.Vector3
function BoneInstance:setScale(value)
	self.scale:from(value:get())
end

do
	local workingTransform = love.math.newTransform()

	--- @param transform? love.Transform
	--- @return love.Transform
	function BoneInstance:composeTransform(transform)
		transform = transform or love.math.newTransform()

		Transform.compose(
			self.translation,
			self.rotation,
			self.scale,
			workingTransform
		)
		transform:apply(workingTransform)

		return transform
	end
end

function BoneInstance:zero()
	self.translation:from(Vector3.ZERO:get())
	self.rotation:from(Quaternion.ZERO:get())
	self.scale:from(Vector3.ZERO:get())
end

function BoneInstance:identity()
	self.translation:from(Vector3.ZERO:get())
	self.rotation:from(Quaternion.IDENTITY:get())
	self.scale:from(Vector3.ONE:get())
end

function BoneInstance:reset()
	self.translation:from(self.bone:getTranslation():get())
	self.rotation:from(self.bone:getRotation():get())
	self.scale:from(self.bone:getScale():get())
end

return BoneInstance
