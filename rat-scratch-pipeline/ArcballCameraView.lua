local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-Math").Vector3
local Quaternion = require("rat-scratch-Math").Quaternion
local Transform = require("rat-scratch-math").Transform
local CameraView = require("rat-scratch-pipeline.CameraView")

--- @class RatScratch.Pipeline.ArcballCameraView : RatScratch.Pipeline.CameraView
--- @field private distance number
--- @field private translation RatScratch.Math.Vector3
--- @field private rotation RatScratch.Math.Quaternion
--- @overload fun(): RatScratch.Pipeline.ArcballCameraView
local ArcballCameraView = Object(CameraView)

function ArcballCameraView:new()
	CameraView.new(self)

	self.distance = 0
	self.translation = Vector3(0)
	self.rotation = Quaternion()
end

--- @param value number
function ArcballCameraView:setDistance(value)
	self.distance = value
	self:dirty()
end

--- @return number
function ArcballCameraView:getDistance()
	return self.distance
end

--- @param value RatScratch.Math.Quaternion
function ArcballCameraView:setRotation(value)
	self.rotation:from(value:get())
	self:dirty()
end

--- @return RatScratch.Math.Quaternion
function ArcballCameraView:getRotation()
	return self.rotation
end

--- @param value RatScratch.Math.Vector3
function ArcballCameraView:setTranslation(value)
	self.translation:from(value:get())
	self:dirty()
end

--- @return RatScratch.Math.Vector3
function ArcballCameraView:getTranslation()
	return self.translation
end

do
	local _zoom = Vector3()
	local _translationTransform = love.math.newTransform()
	local _rotationTransform = love.math.newTransform()
	local _zoomTransform = love.math.newTransform()

	--- @param transform? love.Transform
	--- @return love.Transform
	function ArcballCameraView:getView(transform)
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

return ArcballCameraView
