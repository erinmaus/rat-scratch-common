local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.CameraFrame : RatScratch.Common.BaseObject
--- @field private camera RatScratch.Pipeline.Camera
--- @field private data number[]
--- @field private currentView love.Transform
--- @field private currentInverseView love.Transform
--- @field private currentProjection love.Transform
--- @field private currentInverseProjection love.Transform
--- @field private currentProjectionView love.Transform
--- @field private currentInverseProjectionView love.Transform
--- @field private previousView love.Transform
--- @field private previousInverseView love.Transform
--- @field private previousProjection love.Transform
--- @field private previousInverseProjection love.Transform
--- @field private previousProjectionView love.Transform
--- @field private previousInverseProjectionView love.Transform
--- @overload fun(camera: RatScratch.Pipeline.Camera): RatScratch.Pipeline.CameraFrame
local CameraFrame = Object()

CameraFrame.CAMERA_FORMAT = {
	{ location = 0, name = "viewTransform", format = "floatmat4x4" },
	{ location = 1, name = "inverseViewTransform", format = "floatmat4x4" },
	{ location = 2, name = "previousViewTransform", format = "floatmat4x4" },
	{
		location = 3,
		name = "inversePreviousViewTransform",
		format = "floatmat4x4",
	},
	{ location = 4, name = "projectionTransform", format = "floatmat4x4" },
	{
		location = 5,
		name = "inverseProjectionTransform",
		format = "floatmat4x4",
	},
	{
		location = 6,
		name = "previousProjectionTransform",
		format = "floatmat4x4",
	},
	{
		location = 7,
		name = "inversePreviousProjectionTransform",
		format = "floatmat4x4",
	},
	{ location = 8, name = "projectionViewTransform", format = "floatmat4x4" },
	{
		location = 9,
		name = "inverseProjectionViewTransform",
		format = "floatmat4x4",
	},
	{
		location = 10,
		name = "inversePreviousProjectionViewTransform",
		format = "floatmat4x4",
	},
	{ location = 11, name = "left", format = "floatvec4" },
	{ location = 12, name = "right", format = "floatvec4" },
	{ location = 13, name = "top", format = "floatvec4" },
	{ location = 14, name = "bottom", format = "floatvec4" },
	{ location = 15, name = "near", format = "floatvec4" },
	{ location = 16, name = "far", format = "floatvec4" },
}

CameraFrame.CAMERA_FORMAT_INSTANCE = BufferFormat.get(CameraFrame.CAMERA_FORMAT)

--- @param camera RatScratch.Pipeline.Camera
function CameraFrame:new(camera)
	self.camera = camera

	self.data = {}
	BufferFormat.resetValue(CameraFrame.CAMERA_FORMAT_INSTANCE, self.data)

	self.currentView = love.math.newTransform()
	self.currentInverseView = love.math.newTransform()
	self.currentProjection = love.math.newTransform()
	self.currentInverseProjection = love.math.newTransform()
	self.currentProjectionView = love.math.newTransform()
	self.currentInverseProjectionView = love.math.newTransform()
	self.previousView = love.math.newTransform()
	self.previousInverseView = love.math.newTransform()
	self.previousProjection = love.math.newTransform()
	self.previousInverseProjection = love.math.newTransform()
	self.previousProjectionView = love.math.newTransform()
	self.previousInverseProjectionView = love.math.newTransform()

	-- Cycle twice so 'previous' has 'current'
	self:update()
	self:update()
end

--- @private
--- @param name string
--- @param transform love.Transform
function CameraFrame:_setMatrix(name, transform)
	local count, offset =
		CameraFrame.CAMERA_FORMAT_INSTANCE:getCountOffset(name)

	Table.copy(
		self.data,
		offset,
		offset + count - 1,
		Transform.getTransposedMatrix(transform)
	)
end

--- @private
function CameraFrame:_updatePreviousCameraTransforms()
	self.previousView:setMatrix(self.currentView:getMatrix())
	self.previousInverseView:setMatrix(self.currentInverseView:getMatrix())
	self.previousProjection:setMatrix(self.currentProjection:getMatrix())
	self.previousInverseProjection:setMatrix(
		self.currentInverseProjection:getMatrix()
	)
	self.previousProjectionView:setMatrix(
		self.currentProjectionView:getMatrix()
	)
	self.previousInverseProjectionView:setMatrix(
		self.currentInverseProjectionView:getMatrix()
	)
end

--- @private
function CameraFrame:_updateCurrentCameraTransforms()
	self.camera:getProjectionTransform(self.currentProjection)
	self.camera:getViewTransform(self.currentView)

	self.currentProjectionView:reset()
	self.currentProjectionView:apply(self.currentProjection)
	self.currentProjectionView:apply(self.currentView)

	self.currentInverseView:inverseOf(self.currentView)
	self.currentInverseProjection:inverseOf(self.currentProjection)
	self.currentInverseProjectionView:inverseOf(self.currentProjectionView)
end

--- @private
function CameraFrame:_updateCameraData()
	self:_setMatrix("viewTransform", self.currentView)
	self:_setMatrix("inverseViewTransform", self.currentInverseView)
	self:_setMatrix("previousViewTransform", self.previousView)
	self:_setMatrix("inversePreviousViewTransform", self.currentInverseView)
	self:_setMatrix("projectionTransform", self.currentProjection)
	self:_setMatrix("inverseProjectionTransform", self.currentInverseProjection)
	self:_setMatrix(
		"inversePreviousProjectionTransform",
		self.previousInverseProjection
	)
	self:_setMatrix("previousProjectionTransform", self.previousProjection)
	self:_setMatrix("projectionViewTransform", self.currentProjectionView)
	self:_setMatrix(
		"inverseProjectionViewTransform",
		self.currentInverseProjectionView
	)
	self:_setMatrix(
		"inversePreviousProjectionViewTransform",
		self.previousInverseProjectionView
	)
end

--- @private
--- @param name string
--- @param x number
--- @param y number
--- @param z number
--- @param d number
function CameraFrame:_updatePlane(name, x, y, z, d)
	local inverseLength = 1 / math.sqrt(x ^ 2 + y ^ 2 + z ^ 2)
	BufferFormat.setValue(
		CameraFrame.CAMERA_FORMAT_INSTANCE,
		self.data,
		name,
		0,
		x * inverseLength,
		y * inverseLength,
		z * inverseLength,
		d * inverseLength
	)
end

--- @private
function CameraFrame:_updatePlanesData()
	local m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44 =
		self.currentProjectionView:getMatrix()

	self:_updatePlane("left", m41 + m11, m42 + m12, m43 + m13, m44 + m14)
	self:_updatePlane("right", m41 - m11, m42 - m12, m43 - m13, m44 - m14)
	self:_updatePlane("top", m41 - m21, m42 - m22, m43 - m23, m44 - m24)
	self:_updatePlane("bottom", m41 + m21, m42 + m22, m43 + m23, m44 + m24)
	self:_updatePlane("near", m41 + m31, m42 + m32, m43 + m33, m44 + m34)
	self:_updatePlane("far", m41 - m31, m42 - m32, m43 - m33, m44 - m34)
end

function CameraFrame:update()
	self:_updatePreviousCameraTransforms()
	self:_updateCurrentCameraTransforms()

	self:_updateCameraData()
	self:_updatePlanesData()
end

function CameraFrame:getData()
	return self.data
end

return CameraFrame
