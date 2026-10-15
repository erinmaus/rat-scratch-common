local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert

--- @alias RatScratch.Pipeline.RenderPass.DependencyRequirementType "soft" | "hard"

--- @class RatScratch.Pipeline.RenderPass : RatScratch.Common.BaseObject
--- @field private isReady boolean
--- @field private quality string
--- @field private world RatScratch.Pipeline.World
--- @field private scene RatScratch.Pipeline.Scene
--- @field private dependencyRequirements table<RatScratch.Pipeline.RenderPass, RatScratch.Pipeline.RenderPass.DependencyRequirementType>
--- @field private dependency table<RatScratch.Pipeline.RenderPass, RatScratch.Pipeline.RenderPass | false>
--- @overload fun(): RatScratch.Pipeline.RenderPass
local RenderPass = Object()

function RenderPass:new()
	self.isReady = false
	self.dependencyRequirements = {}
	self.dependencies = {}
end

--- @protected
--- @generic T : RatScratch.Pipeline.RenderPass
--- @param renderPassType T | RatScratch.Pipeline.RenderPass | unknown
--- @param dependencyRequirementType RatScratch.Pipeline.RenderPass.DependencyRequirementType
function RenderPass:addDependencyRequirement(
	renderPassType,
	dependencyRequirementType
)
	assert(
		not self.dependencyRequirements[renderPassType],
		"render pass already has '%s' dependency on '%s'",
		renderPassType._DEBUG.shortName
	)

	self.dependencyRequirements[renderPassType] = dependencyRequirementType
	self.dependencies[renderPassType] = false
end

--- @generic T : RatScratch.Pipeline.RenderPass
--- @param dependency T | RatScratch.Pipeline.RenderPass | unknown
function RenderPass:addDependency(dependency)
	local dependencyType = dependency:getType()
	assert(
		self.dependencyRequirements[dependencyType],
		"dependency type '%s' not required",
		dependencyType._DEBUG.shortName
	)

	self.dependencies[dependencyType] = dependency
end

--- @generic T : RatScratch.Pipeline.RenderPass
--- @param dependencyType T | RatScratch.Pipeline.RenderPass | unknown
--- @return T
function RenderPass:getDependency(dependencyType)
	local requirement = self.dependencyRequirements[dependencyType]
	assert(
		requirement ~= "soft" or self.dependencies[dependencyType] ~= nil,
		"dependency type '%s' is soft and not present; check with hasDependency first",
		dependencyType._DEBUG.shortName
	)

	return self.dependencies[dependencyType]
end

--- @generic T : RatScratch.Pipeline.RenderPass
--- @param dependencyType T | RatScratch.Pipeline.RenderPass | unknown
--- @return boolean
function RenderPass:hasDependency(dependencyType)
	assert(
		self.dependencyRequirements[dependencyType],
		"dependency type '%s' not required",
		dependencyType._DEBUG.shortName
	)

	return self.dependencies[dependencyType] ~= nil
end

--- @param quality string
--- @param world RatScratch.Pipeline.World
--- @param scene RatScratch.Pipeline.Scene
function RenderPass:attach(quality, world, scene)
	assert(not self.isReady, "render pass was already attached")
	for dependencyType, dependencyRequirement in
		pairs(self.dependencyRequirements)
	do
		assert(
			dependencyRequirement == "soft" or self.dependencies[dependencyType],
			"unsatisified 'hard' dependency: %s",
			dependencyType._DEBUG.shortName
		)
	end

	self.quality = quality
	self.world = world
	self.scene = scene

	self.isReady = true
	self:attached()
end

--- @protected
function RenderPass:attached()
	-- Nothing.
end

function RenderPass:getIsAttached()
	return self.isReady
end

function RenderPass:getQualityPreset()
	assert(self.isReady, "render pass was not attached")
	return self.quality
end

--- @return RatScratch.Pipeline.World
function RenderPass:getWorld()
	assert(self.isReady, "render pass was not attached")
	return self.world
end

--- @return RatScratch.Pipeline.Scene
function RenderPass:getScene()
	assert(self.isReady, "render pass was not attached")
	return self.scene
end

function RenderPass:getPipelineRuntime()
	assert(self.isReady, "render pass was not attached")
	return self.world:getPipelineRuntime()
end

function RenderPass:getPipelineConfig()
	assert(self.isReady, "render pass was not attached")
	return self.world:getPipelineConfig()
end

--- @param shader love.Shader
function RenderPass:bind(shader)
	-- Nothing.
end

function RenderPass:start()
	love.graphics.push()
end

function RenderPass:stop()
	love.graphics.pop()
end

function RenderPass:draw(pipelineRenderer)
	-- Nothing.
end

return RenderPass
