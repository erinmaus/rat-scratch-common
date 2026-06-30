local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Animation = require("rat-scratch-graphics.Graphics3D.Animation")
local AnimationChannel =
	require("rat-scratch-graphics.Graphics3D.AnimationChannel")
local Bone = require("rat-scratch-graphics.Graphics3D.Bone")
local KeyFrames = require("rat-scratch-graphics.Graphics3D.KeyFrames")
local Material = require("rat-scratch-graphics.Graphics3D.Material")
local Mesh = require("rat-scratch-graphics.Graphics3D.Mesh")
local Model = require("rat-scratch-graphics.Graphics3D.Model")
local Skeleton = require("rat-scratch-graphics.Graphics3D.Skeleton")
local Quaternion = require("rat-scratch-math").Quaternion
local Vector3 = require("rat-scratch-math").Vector3
local SkinnedModel = require("rat-scratch-graphics.Graphics3D.SkinnedModel")

--- @class RatScratch.Graphics.Graphics3D.Scene : RatScratch.Common.BaseObject
--- @overload fun(name?: string, models: RatScratch.Graphics.Graphics3D.Model[]):RatScratch.Graphics.Graphics3D.Scene
--- @field private name string
--- @field private models RatScratch.Graphics.Graphics3D.Model[]
--- @field private modelsByName table<string, RatScratch.Graphics.Graphics3D.Model>
local Scene = Object()

--- @param inputModels RatScratch.Graphics.Graphics3D.Model[]
--- @return RatScratch.Graphics.Graphics3D.Model[], table<string, RatScratch.Graphics.Graphics3D.Model>
function Scene.validateModels(inputModels)
	assert(
		#inputModels > 0,
		"must have one or more models; found %d",
		#inputModels
	)

	local models = {}
	local modelsByName = {}
	for _, model in ipairs(inputModels) do
		local name = model:getName()
		if name ~= "" then
			assert(
				not modelsByName[name],
				"model with duplicate name: %s",
				name
			)
			modelsByName[name] = model
		end

		table.insert(models, model)
	end

	return models, modelsByName
end

local function _maybeYield(flag, ...)
	if flag then
		coroutine.yield(...)
	end
end

--- @param sceneDefinition RatScratch.Graphics.Graphics3D.SceneDefinition
--- @param yield? boolean
--- @return RatScratch.Graphics.Graphics3D.Scene
function Scene.fromDefinition(sceneDefinition, yield)
	local models = {}

	_maybeYield(yield, "begin", Scene, sceneDefinition)

	for _, modelDefinition in ipairs(sceneDefinition.models) do
		if modelDefinition.skeleton then
			_maybeYield(yield, "begin", SkinnedModel, modelDefinition)
		else
			_maybeYield(yield, "begin", Model, modelDefinition)
		end

		--- @type RatScratch.Graphics.Graphics3D.Mesh[]
		local meshes = {}

		for _, meshDefinition in ipairs(modelDefinition.meshes) do
			_maybeYield(yield, "begin", Mesh, meshDefinition)

			local buffers = meshDefinition.buffers
			local vertices = meshDefinition.vertices
			local indices = meshDefinition.indices

			local material
			if meshDefinition.material then
				_maybeYield(yield, "begin", Material, meshDefinition.material)

				local texture = meshDefinition.material.texture
				if texture and texture:typeOf("ImageData") then
					--- @cast texture love.ImageData
					texture = love.graphics.newTexture(
						texture,
						{ mipmaps = meshDefinition.material.mipmaps }
					)

					--- @cast texture love.Texture

					if meshDefinition.material.mipmapFilter then
						texture:setMipmapFilter(
							meshDefinition.material.mipmapFilter
						)
					end

					texture:setWrap(
						meshDefinition.material.horizontalWrapMode or "repeat",
						meshDefinition.material.verticalWrapMode or "repeat"
					)

					texture:setFilter(
						meshDefinition.material.minFilter or "linear",
						meshDefinition.material.magFilter or "linear"
					)
				end

				material = Material(texture, meshDefinition.material.color)

				_maybeYield(yield, "load", material)
			end

			local mesh = Mesh(
				meshDefinition.name,
				buffers,
				meshDefinition.format,
				vertices,
				indices,
				material
			)
			table.insert(meshes, mesh)

			_maybeYield(yield, "load", mesh)
		end

		local skeleton
		if modelDefinition.skeleton then
			_maybeYield(yield, "begin", Skeleton, modelDefinition.skeleton)

			local bones = {}

			--- @type table<integer, RatScratch.Graphics.Graphics3D.Bone>
			local bonesByID = {}

			for _, boneDefinition in ipairs(modelDefinition.skeleton.bones) do
				_maybeYield(yield, "begin", Bone, boneDefinition)

				local bone = Bone(
					bonesByID[boneDefinition.parentID],
					boneDefinition.id,
					boneDefinition.name,
					boneDefinition.index,
					boneDefinition.inverseBindPoseTransform,
					{
						transform = boneDefinition.transform,
						translation = Vector3(
							unpack(boneDefinition.translation)
						),
						rotation = Quaternion(unpack(boneDefinition.rotation)),
						scale = Vector3(unpack(boneDefinition.scale)),
					}
				)

				bonesByID[bone:getID()] = bone
				table.insert(bones, bone)

				_maybeYield(yield, "load", bone)
			end

			skeleton = Skeleton(bones)
			_maybeYield(yield, "load", skeleton)
		end

		--- @type RatScratch.Graphics.Graphics3D.Animation[] | nil
		local animations
		if skeleton and modelDefinition.animations then
			animations = {}

			for animationIndex, animationDefinition in
				ipairs(modelDefinition.animations)
			do
				_maybeYield(yield, "begin", Animation, animationDefinition)

				--- @type RatScratch.Graphics.Graphics3D.AnimationChannel[]
				local channels = {}

				for _, channel in ipairs(animationDefinition.channels) do
					if skeleton:hasBoneByID(channel.boneID) then
						_maybeYield(yield, "begin", AnimationChannel, channel)

						--- @type RatScratch.Graphics.Graphics3D.KeyFrames[]
						local keyFrames = {}

						for _, propertyDefinition in ipairs(channel.properties) do
							_maybeYield(
								yield,
								"begin",
								KeyFrames,
								propertyDefinition
							)

							--- @type RatScratch.Graphics.Graphics3D.KeyFrame[]
							local keyFrameValues = {}

							for _, frameDefinition in
								ipairs(propertyDefinition.frames)
							do
								local value
								if
									propertyDefinition.property
										== "position"
									or propertyDefinition.property
										== "scale"
								then
									value = Vector3
								elseif
									propertyDefinition.property == "rotation"
								then
									value = Quaternion
								else
									assert(
										false,
										'expected "position", "scale", or "rotation" for animation %s bone %s key frames, got: %s',
										animationDefinition.name
											or animationIndex,
										skeleton
												and skeleton:getBoneByID(
													channel.boneID
												)
											or channel.boneID,
										propertyDefinition.property
									)
								end

								--- @type RatScratch.Graphics.Graphics3D.KeyFrame
								local keyFrameValue = {
									time = frameDefinition.time,
									inTangent = frameDefinition.inTangent
										and value(
											unpack(frameDefinition.inTangent)
										),
									value = frameDefinition.value
										and value(unpack(frameDefinition.value)),
									outTangent = frameDefinition.outTangent
										and value(
											unpack(frameDefinition.outTangent)
										),
								}

								table.insert(keyFrameValues, keyFrameValue)
							end

							table.insert(
								keyFrames,
								KeyFrames(
									propertyDefinition.property,
									propertyDefinition.interpolation,
									keyFrameValues
								)
							)
							_maybeYield(yield, "load", keyFrames[#keyFrames])
						end

						table.insert(
							channels,
							AnimationChannel(
								skeleton:getBoneByID(channel.boneID),
								keyFrames
							)
						)
						_maybeYield(yield, "load", channels[#channels])
					end
				end

				table.insert(
					animations,
					Animation(animationDefinition.name, channels)
				)
				_maybeYield(yield, "load", animations[#animations])
			end
		end

		if skeleton then
			table.insert(
				models,
				SkinnedModel(
					modelDefinition.name,
					meshes,
					skeleton,
					animations or {}
				)
			)
		else
			table.insert(
				models,
				Model(modelDefinition.name, meshes, modelDefinition.transform)
			)
		end

		_maybeYield(yield, "load", models[#models])
	end

	local scene = Scene(sceneDefinition.name, models)
	_maybeYield(yield, "load", scene)

	return scene
end

--- @param name string?
--- @param models RatScratch.Graphics.Graphics3D.Model[]
function Scene:new(name, models)
	local outputModels, outputModelsByName = Scene.validateModels(models)

	self.name = name or ""
	self.models = outputModels
	self.modelsByName = outputModelsByName
end

function Scene:getName()
	return self.name
end

--- @param key number | string
--- @return RatScratch.Graphics.Graphics3D.Model
function Scene:getModel(key)
	if type(key) == "number" then
		assert(self.models[key] ~= nil, "no model at index %d", key)
		return self.models[key]
	elseif type(key) == "string" then
		assert(
			self.modelsByName[key] ~= nil,
			"no model with given name: %s",
			key
		)
		return self.modelsByName[key]
	end

	error('expected "number" or "string" for parameter "key"')
end

function Scene:getModelCount()
	return #self.models
end

return Scene
