local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local CameraEvent = require("rat-scratch-pipeline.CameraEvent")
local Transform = require("rat-scratch-math.Transform")

--- @generic P : RatScratch.Pipeline.CameraProjection
--- @generic V : RatScratch.Pipeline.CameraView
--- @class RatScratch.Pipeline.Camera<P, V> : RatScratch.Common.BaseObject
--- @field private projection RatScratch.Pipeline.CameraProjection
--- @field private view RatScratch.Pipeline.CameraView
--- @field private projectionTransform love.Transform
--- @field private viewTransform love.Transform
--- @field private isProjectionDirty boolean
--- @field private isViewDirty boolean
--- @overload fun<P, V>(projection: P, view: V): RatScratch.Pipeline.Camera<P, V>
local Camera = Object()

--- @generic P : RatScratch.Pipeline.CameraProjection
--- @generic V : RatScratch.Pipeline.CameraView
--- @param self RatScratch.Pipeline.Camera<P, V>
--- @param projection RatScratch.Pipeline.CameraProjection
--- @param view RatScratch.Pipeline.CameraView
function Camera:new(projection, view)
	self.projection = projection
	self.view = view
	self.projectionTransform = love.math.newTransform()
	self.viewTransform = love.math.newTransform()
	self.isProjectionDirty = true
	self.isViewDirty = true

	projection:listen(CameraEvent.UPDATE, self._onProjectionUpdate, self)
	view:listen(CameraEvent.UPDATE, self._onViewUpdate, self)
end

--- @private
function Camera:_onProjectionUpdate()
	self.isProjectionDirty = true
end

--- @private
function Camera:_onViewUpdate()
	self.isViewDirty = true
end

--- @param transform? love.Transform
--- @return love.Transform
function Camera:getProjectionTransform(transform)
	if self.isProjectionDirty then
		self.projection:getProjection(self.projectionTransform)
		self.isProjectionDirty = false
	end

	transform = transform or love.math.newTransform()
	transform:setMatrix(self.projectionTransform:getMatrix())

	return transform
end

--- @generic P : RatScratch.Pipeline.CameraProjection
--- @generic V : RatScratch.Pipeline.CameraView
--- @param self RatScratch.Pipeline.Camera<P, V>
--- @return P
function Camera:getProjection()
	return self.projection
end

--- @param transform? love.Transform
--- @return love.Transform
function Camera:getViewTransform(transform)
	if self.isViewDirty then
		self.view:getView(self.viewTransform)
		self.isViewDirty = false
	end

	transform = transform or love.math.newTransform()
	transform:setMatrix(self.viewTransform:getMatrix())

	return transform
end

--- @generic P : RatScratch.Pipeline.CameraProjection
--- @generic V : RatScratch.Pipeline.CameraView
--- @param self RatScratch.Pipeline.Camera<P, V>
--- @return V
function Camera:getView()
	return self.view
end

do
	local _projection = love.math.newTransform()
	local _view = love.math.newTransform()

	--- @param position RatScratch.Math.Vector3
	--- @param width integer
	--- @param height integer
	--- @param result? RatScratch.Math.Vector3
	--- @return RatScratch.Math.Vector3
	function Camera:project(position, width, height, result)
		local p = self:getProjectionTransform(_projection)
		local v = self:getViewTransform(_view)

		p:apply(v)

		return Transform.project(p, position, 0, 0, width, height, result)
	end
end

do
	local _projection = love.math.newTransform()
	local _view = love.math.newTransform()

	--- @param position RatScratch.Math.Vector3
	--- @param width integer
	--- @param height integer
	--- @param result? RatScratch.Math.Vector3
	--- @return RatScratch.Math.Vector3
	function Camera:unproject(position, width, height, result)
		local p = self:getProjectionTransform(_projection)
		local v = self:getViewTransform(_view)

		p:apply(v)
		p:inverseOf(p)

		return Transform.unproject(p, position, 0, 0, width, height, result)
	end
end

return Camera
