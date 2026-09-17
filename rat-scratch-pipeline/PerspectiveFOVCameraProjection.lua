local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-Math").Vector3
local Quaternion = require("rat-scratch-Math").Quaternion
local Transform = require("rat-scratch-math").Transform
local CameraProjection = require("rat-scratch-pipeline.CameraProjection")

--- @class RatScratch.Pipeline.PerspectiveFOVCameraProjection : RatScratch.Pipeline.CameraProjection
--- @field private fov number
--- @field private width integer
--- @field private height integer
--- @field private near number
--- @field private far number
--- @overload fun(): RatScratch.Pipeline.PerspectiveFOVCameraProjection
local PerspectiveFOVCameraProjection = Object(CameraProjection)

function PerspectiveFOVCameraProjection:new()
	CameraProjection.new(self)

	self.fov = math.rad(90)
	self.width = 1
	self.height = 1
	self.near = 0.1
	self.far = 1000
end

--- @param value number
function PerspectiveFOVCameraProjection:setFOV(value)
	self.fov = value
	self:dirty()
end

function PerspectiveFOVCameraProjection:getFOV()
	return self.fov
end

function PerspectiveFOVCameraProjection:getSize()
	return self.width, self.height
end

--- @param width integer
--- @param height integer
function PerspectiveFOVCameraProjection:setSize(width, height)
	self.width = width
	self.height = height
	self:dirty()
end

function PerspectiveFOVCameraProjection:getAspectRatio()
	return self.width / self.height
end

--- @param value number
function PerspectiveFOVCameraProjection:setNear(value)
	self.near = value
	self:dirty()
end

--- @return number
function PerspectiveFOVCameraProjection:getNear()
	return self.near
end

--- @param value number
function PerspectiveFOVCameraProjection:setFar(value)
	self.far = value
	self:dirty()
end

--- @return number
function PerspectiveFOVCameraProjection:getFar()
	return self.far
end

--- @param transform? love.Transform
--- @return love.Transform
function PerspectiveFOVCameraProjection:getProjection(transform)
	return Transform.makePerspectiveTransform(
		self.fov,
		self.width / self.height,
		self.near,
		self.far,
		transform
	)
end

return PerspectiveFOVCameraProjection
