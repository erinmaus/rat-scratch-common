local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
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

--- @param textureDefinition RatScratch.Graphics.Graphics3D.MaterialDefinitionTexture
--- @param linear? boolean
--- @return love.Texture?
local function _materialToTexture(textureDefinition, linear)
	if not textureDefinition then
		return
	end

	local textureOrImageData = textureDefinition.texture
	if not textureOrImageData then
		return nil
	end

	--- @type love.Texture
	local texture
	if textureOrImageData:typeOf("ImageData") then
		texture = love.graphics.newTexture(textureOrImageData, {
			linear = linear,
			mipmaps = textureDefinition.mipmaps and "auto" or false,
		})
	else
		--- @cast textureOrImageData love.Texture
		texture = textureOrImageData
	end

	if textureDefinition.mipmapFilter then
		texture:setMipmapFilter(textureDefinition.mipmapFilter)
	end

	texture:setWrap(
		textureDefinition.horizontalWrapMode or "repeat",
		textureDefinition.verticalWrapMode or "repeat"
	)

	texture:setFilter(
		textureDefinition.minFilter or "linear",
		textureDefinition.magFilter or "linear"
	)

	return texture
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

				local materialDefinition = meshDefinition.material
				--- @cast materialDefinition RatScratch.Graphics.Graphics3D.MaterialDefinition

				local albedoTexture =
					_materialToTexture(materialDefinition.texture)
				_maybeYield(
					yield and albedoTexture,
					"step",
					Material,
					meshDefinition.material
				)
				local normalTexture =
					_materialToTexture(materialDefinition.normalTexture)
				_maybeYield(
					yield and normalTexture,
					"step",
					Material,
					meshDefinition.material
				)
				local occlusionTexture =
					_materialToTexture(materialDefinition.occlusionTexture)
				_maybeYield(
					yield and occlusionTexture,
					"step",
					Material,
					meshDefinition.material
				)
				local metalRoughnessTexture =
					_materialToTexture(materialDefinition.metalRoughnessTexture)
				_maybeYield(
					yield and metalRoughnessTexture,
					"step",
					Material,
					meshDefinition.material
				)
				local emissiveTexture =
					_materialToTexture(materialDefinition.emissiveTexture)
				_maybeYield(
					yield and emissiveTexture,
					"step",
					Material,
					meshDefinition.material
				)

				material = Material()
				if
					materialDefinition.texture
					and materialDefinition.texture.albedoFactor
				then
					material:setColor(
						Table.unpack(
							materialDefinition.texture.albedoFactor,
							1,
							4
						)
					)
				end

				if
					materialDefinition.normalTexture
					and materialDefinition.normalTexture.normalScale
				then
					material:setNormalScale(
						materialDefinition.normalTexture.normalScale
					)
				end

				if
					materialDefinition.occlusionTexture
					and materialDefinition.occlusionTexture.occlusionStrength
				then
					material:setOcclusion(
						materialDefinition.occlusionTexture.occlusionStrength
					)
				end

				if
					materialDefinition.metalRoughnessTexture
					and materialDefinition.metalRoughnessTexture.metalFactor
				then
					material:setMetal(
						materialDefinition.metalRoughnessTexture.metalFactor
					)
				end

				if
					materialDefinition.metalRoughnessTexture
					and materialDefinition.metalRoughnessTexture.roughnessFactor
				then
					material:setRoughness(
						materialDefinition.metalRoughnessTexture.roughnessFactor
					)
				end
				if
					materialDefinition.emissiveTexture
					and materialDefinition.emissiveTexture.emissiveFactor
				then
					material:setColor(
						Table.unpack(
							materialDefinition.emissiveTexture.emissiveFactor,
							1,
							3
						)
					)
				end

				if materialDefinition.alphaCutoff then
					material:setAlphaCutoff(materialDefinition.alphaCutoff)
				end

				material:setTexture(albedoTexture)
				material:setNormalTexture(normalTexture)
				material:setOcclusionTexture(occlusionTexture)
				material:setMetalRoughnessTexture(metalRoughnessTexture)
				material:setEmissiveTexture(emissiveTexture)

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
