local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-Math").Vector3
local Quaternion = require("rat-scratch-Math").Quaternion
local Transform = require("rat-scratch-math").Transform
local Camera = require("rat-scratch-pipeline.Camera")

--- @class RatScratch.Pipeline.ArcballCamera : RatScratch.Common.BaseObject
--- @field private distance number
--- @field private translation RatScratch.Math.Vector3
--- @field private rotation RatScratch.Math.Quaternion
--- @field private fov number
--- @field private width integer
--- @field private height integer
--- @field private near number
--- @field private far number
--- @overload fun(): RatScratch.Pipeline.ArcballCamera
local ArcballCamera = Object(Camera)

function ArcballCamera:new()
	self.distance = 0
	self.translation = Vector3(0)
	self.rotation = Quaternion()
	self.fov = math.rad(90)
	self.width = 1
	self.height = 1
	self.near = 0.1
	self.far = 1000
end

--- @param value number
function ArcballCamera:setDistance(value)
	self.distance = value
end

--- @return number
function ArcballCamera:getDistance()
	return self.distance
end

--- @param value RatScratch.Math.Quaternion
function ArcballCamera:setRotation(value)
	self.rotation:from(value:get())
end

--- @return RatScratch.Math.Quaternion
function ArcballCamera:getRotation()
	return self.rotation
end

--- @param value RatScratch.Math.Vector3
function ArcballCamera:setTranslation(value)
	self.translation:from(value:get())
end

--- @return RatScratch.Math.Vector3
function ArcballCamera:getTranslation()
	return self.translation
end

--- @param value number
function ArcballCamera:setFOV(value)
	self.fov = value
end

function ArcballCamera:getFOV()
	return self.fov
end

function ArcballCamera:getSize()
	return self.width, self.height
end

--- @param width integer
--- @param height integer
function ArcballCamera:setSize(width, height)
	self.width = width
	self.height = height
end

function ArcballCamera:getAspectRatio()
	return self.width / self.height
end

--- @param value number
function ArcballCamera:setNear(value)
	self.near = value
end

--- @return number
function ArcballCamera:getNear()
	return self.near
end

--- @param value number
function ArcballCamera:setFar(value)
	self.far = value
end

--- @return number
function ArcballCamera:getFar()
	return self.far
end

--- @param transform? love.Transform
--- @return love.Transform
function ArcballCamera:getProjection(transform)
	return Transform.makePerspectiveTransform(
		self.fov,
		self.width / self.height,
		self.near,
		self.far,
		transform
	)
end

do
	local _zoom = Vector3()
	local _translationTransform = love.math.newTransform()
	local _rotationTransform = love.math.newTransform()
	local _zoomTransform = love.math.newTransform()

	--- @param transform? love.Transform
	--- @return love.Transform
	function ArcballCamera:getView(transform)
		local translation = Transform.makeTranslationTransform(
			self.translation,
			_translationTransform
		)
		local rotation =
			Transform.makeRotationTransform(self.rotation, _rotationTransform)
		local zoom = Transform.makeTranslationTransform(
			_zoom:from(0, 0, self.distance),
			_zoomTransform
		)

		transform = transform or love.math.newTransform()
		transform:reset()
		transform:apply(translation)
		transform:apply(rotation)
		transform:apply(zoom)
		transform:inverseOf(transform)

		return transform
	end
end

do
	local _zoom = Vector3()

	--- @param result? RatScratch.Math.Vector3
	--- @return RatScratch.Math.Vector3
	function ArcballCamera:getEye(result)
		result = result or Vector3()
		return self.rotation
			:transformVector(_zoom:from(0, 0, self.distance), result)
			:add(self.translation, result)
	end
end

return ArcballCamera
