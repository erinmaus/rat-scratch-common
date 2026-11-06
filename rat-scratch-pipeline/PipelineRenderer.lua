local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local AnimationPipeline = require("rat-scratch-pipeline.AnimationPipeline")
local DrawPipeline = require("rat-scratch-pipeline.DrawPipeline")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local ModelPipeline = require("rat-scratch-pipeline.ModelPipeline")
local ObjectPipeline = require("rat-scratch-pipeline.ObjectPipeline")
local World = require("rat-scratch-pipeline.World")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local IndirectDraw = require("rat-scratch-pipeline.IndirectDraw")
local PostProcess = require("rat-scratch-pipeline.PostProcess")
local ReflectionProbePipeline =
	require("rat-scratch-pipeline.ReflectionProbePipeline")

--- @class RatScratch.Pipeline.PipelineRenderer : RatScratch.Common.BaseObject
--- @field private pipelineRuntime RatScratch.Pipeline.PipelineRuntime
--- @field private world RatScratch.Pipeline.World
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.PipelineRenderer
local PipelineRenderer = Object()

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function PipelineRenderer:new(pipelineRuntime)
	self.pipelineRuntime = pipelineRuntime
	self.world = World(pipelineRuntime)

	self.indirectDrawBufferData = {}
	BufferFormat.resetValue(
		DrawPipeline.INDIRECT_DRAW_FORMAT,
		self.indirectDrawBufferData
	)
	BufferFormat.setValue(
		IndirectDraw.INDIRECT_DRAW_FORMAT,
		self.indirectDrawBufferData,
		"vertexCount",
		0,
		pipelineRuntime:getConfig():getMeshletFormat():getTriangleCount() * 3
	)

	self.cullShader = pipelineRuntime:loadComputeShader(
		"@Pipeline/Cull/Cull.compute.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)

	self.generateHiZShader = pipelineRuntime:loadComputeShader(
		"@Pipeline/HiZ/Generate.compute.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)

	self.prepareCubeMapHiZShader = pipelineRuntime:loadShader(
		"@Pipeline/HiZ/PrepareCubeMap.frag.glsl",
		"@Pipeline/PostProcess/SubsetLayeredVertex.vert.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)

	self.prepareDepthSortIndirectShader = pipelineRuntime:loadComputeShader(
		"@Pipeline/SortDraws/PrepareIndirect.compute.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)

	self.prepareDepthSortShader = pipelineRuntime:loadComputeShader(
		"@Pipeline/SortDraws/PrepareSort.compute.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)

	self.depthSortDrawsShader = pipelineRuntime:loadComputeShader(
		"@Pipeline/SortDraws/SortDraws.compute.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)

	self.finishDepthSortShader = pipelineRuntime:loadComputeShader(
		"@Pipeline/SortDraws/FinishSort.compute.glsl",
		pipelineRuntime:getDefaultQualityPreset()
	)
end

function PipelineRenderer:getWorld()
	return self.world
end

function PipelineRenderer:update()
	self.world:flush()
end

--- @private
--- @param shader love.Shader
--- @param qualityPreset string
function PipelineRenderer:_bindWorldUniforms(shader, qualityPreset)
	local material = self.world:getPipeline(MaterialPipeline)
	material:bind(shader, qualityPreset)

	local model = self.world:getPipeline(ModelPipeline)
	model:bind(shader, qualityPreset)

	local object = self.world:getPipeline(ObjectPipeline)
	object:bind(shader, qualityPreset)

	local animation = self.world:getPipeline(AnimationPipeline)
	animation:bind(shader, qualityPreset)
end

--- @private
--- @param shader love.Shader
--- @param scene RatScratch.Pipeline.Scene
--- @param qualityPreset string
function PipelineRenderer:_bindSceneUniforms(shader, scene, qualityPreset)
	local draw = scene:getPipeline(DrawPipeline)
	draw:bind(shader, qualityPreset)

	local light = scene:getPipeline(LightPipeline)
	light:bind(shader, qualityPreset)

	local reflection = scene:getPipeline(ReflectionProbePipeline)
	reflection:bind(shader, qualityPreset)

	scene:bind(shader, qualityPreset)
end

--- @private
--- @param result RatScratch.Pipeline.HiZResult
function PipelineRenderer:_prepareCubeMapHiZ(result)
	if not self.prepareCubeMapHiZShader:getIsReady() then
		return
	end

	local prepareShader = self.prepareCubeMapHiZShader:get()

	local depthRenderBuffer = result:getSourceRenderBuffer()

	local hiZRenderBuffer = result:getDestinationRenderBuffer()
	hiZRenderBuffer:resize(
		depthRenderBuffer:getWidth(),
		depthRenderBuffer:getHeight(),
		depthRenderBuffer:getLayers()
	)

	result:getCamerasBuffer():bind(prepareShader)

	if prepareShader:hasUniform("rat_LayersBuffer") then
		prepareShader:send(
			"rat_LayersBuffer",
			result:getCamerasBuffer():getActiveCameraBuffer():getBuffer()
		)
	end

	if prepareShader:hasUniform("rat_DepthTexture") then
		prepareShader:send(
			"rat_DepthTexture",
			depthRenderBuffer:getDepthCanvasMipmap(1)
		)
	end

	love.graphics.push("all")
	do
		love.graphics.setBlendState("add", "one", "zero")
		love.graphics.setDepthMode()

		hiZRenderBuffer:bind()
		love.graphics.clear(0, 0, 0, 0)

		love.graphics.setShader(prepareShader)
		PostProcess.drawInstanced(
			result:getCamerasBuffer():getActiveCameraCount()
		)
	end
	love.graphics.pop()
end

--- @private
--- @param result RatScratch.Pipeline.HiZResult
function PipelineRenderer:_generateHiZ(result)
	if not self.generateHiZShader:getIsReady() then
		return
	end

	local generateShader = self.generateHiZShader:get()
	local localX, localY, localZ = generateShader:getLocalThreadgroupSize()

	result:getCamerasBuffer():bind(generateShader)
	if generateShader:hasUniform("rat_LayersBuffer") then
		generateShader:send(
			"rat_LayersBuffer",
			result:getCamerasBuffer():getActiveCameraBuffer():getBuffer()
		)
	end

	local hiZRenderBuffer = result:getDestinationRenderBuffer()
	for i = 2, hiZRenderBuffer:getMipmapCount() do
		local source = hiZRenderBuffer:getCanvasMipmap(1, i - 1)
		local destination = hiZRenderBuffer:getCanvasMipmap(1, i)

		if generateShader:hasUniform("rat_Source") then
			generateShader:send("rat_Source", source)
		end

		if generateShader:hasUniform("rat_Destination") then
			generateShader:send("rat_Destination", destination)
		end

		love.graphics.dispatchThreadgroups(
			generateShader,
			math.max(math.ceil(destination:getWidth() / localX), 1),
			math.max(math.ceil(destination:getHeight() / localY), 1),
			math.max(
				math.ceil(
					result:getCamerasBuffer():getActiveCameraCount() / localZ
				),
				1
			)
		)
	end
end

--- @param qualityPreset string
--- @param result RatScratch.Pipeline.HiZResult
function PipelineRenderer:computeCubeMapHiZ(qualityPreset, result)
	self:_prepareCubeMapHiZ(result)
	self:_generateHiZ(result)
end

--- @param qualityPreset string
--- @param scene RatScratch.Pipeline.Scene
--- @param result RatScratch.Pipeline.CullResult
function PipelineRenderer:cull(qualityPreset, scene, result)
	if not self.cullShader:getIsReady() then
		return
	end

	local cullShader = self.cullShader:get()

	self:_bindWorldUniforms(cullShader, qualityPreset)
	self:_bindSceneUniforms(cullShader, scene, qualityPreset)

	result:getIndirectDrawBuffer():setArrayData(self.indirectDrawBufferData)

	local draw = scene:getPipeline(DrawPipeline)
	local inputDrawsBuffer = draw:getDrawsBuffer()
	local _, inputDrawCount = inputDrawsBuffer:getIndexCount()
	result:reserveDraws(inputDrawCount)

	local cameraCount = result:getCamerasBuffer():getActiveCameraCount()

	if cullShader:hasUniform("rat_DrawsBuffer") then
		cullShader:send("rat_DrawsBuffer", inputDrawsBuffer:getBuffer())
	end

	if cullShader:hasUniform("rat_OutputDrawsBuffer") then
		cullShader:send("rat_OutputDrawsBuffer", result:getDrawsBuffer())
	end

	if cullShader:hasUniform("rat_IndirectDrawsBuffer") then
		cullShader:send(
			"rat_IndirectDrawsBuffer",
			result:getIndirectDrawBuffer()
		)
	end

	if cullShader:hasUniform("rat_DrawCount") then
		cullShader:send("rat_DrawCount", inputDrawCount)
	end

	result:getCamerasBuffer():bind(cullShader)

	local localX, localY = cullShader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		cullShader,
		math.max(math.ceil(inputDrawCount / localX), 1),
		math.max(math.ceil(cameraCount / localY), 1)
	)
end

PipelineRenderer.SORT_SIGN_FORWARD = 1
PipelineRenderer.SORT_SIGN_DEFERRED = -1

--- @private
--- @param result RatScratch.Pipeline.CullResult
function PipelineRenderer:_prepareSortIndirect(result)
	if not self.prepareDepthSortIndirectShader:getIsReady() then
		return
	end

	if not self.prepareDepthSortShader:getIsReady() then
		return
	end

	if not self.finishDepthSortShader:getIsReady() then
		return
	end

	local localX1 = self.prepareDepthSortShader:get():getLocalThreadgroupSize()
	local localX2 = self.finishDepthSortShader:get():getLocalThreadgroupSize()

	assert(
		localX1 == localX2,
		"'@Pipeline/SortDraws/PrepareSort.compute.glsl' (local size x = %d) and '@Pipeline/SortDraws/FinishSort.compute.glsl' (local size x = %d) local size mis-match",
		localX1,
		localX2
	)

	local shader = self.prepareDepthSortIndirectShader:get()
	local minLocalX = math.min(localX1, localX2)

	if shader:hasUniform("rat_LocalThreadgroupSizeX") then
		shader:send("rat_LocalThreadgroupSizeX", minLocalX)
	end

	if shader:hasUniform("rat_IndirectDrawsBuffer") then
		shader:send("rat_IndirectDrawsBuffer", result:getIndirectDrawBuffer())
	end

	if shader:hasUniform("rat_IndirectDispatchesBuffer") then
		shader:send(
			"rat_IndirectDispatchesBuffer",
			result:getIndirectDispatchBuffer()
		)
	end

	love.graphics.dispatchThreadgroups(shader, 1)
end

--- @private
--- @param qualityPreset string
--- @param scene RatScratch.Pipeline.Scene
--- @param result RatScratch.Pipeline.CullResult
--- @param sign -1 | 1
function PipelineRenderer:_prepareSort(qualityPreset, scene, result, sign)
	if not self.prepareDepthSortShader:getIsReady() then
		return
	end

	local shader = self.prepareDepthSortShader:get()
	self:_bindWorldUniforms(shader, qualityPreset)
	self:_bindSceneUniforms(shader, scene, qualityPreset)

	if shader:hasUniform("rat_DepthSign") then
		shader:send("rat_DepthSign", sign)
	end

	if shader:hasUniform("rat_IndirectDrawsBuffer") then
		shader:send("rat_IndirectDrawsBuffer", result:getIndirectDrawBuffer())
	end

	if shader:hasUniform("rat_DrawsBuffer") then
		shader:send("rat_DrawsBuffer", result:getDrawsBuffer())
	end

	if shader:hasUniform("rat_SortedClusterElementsBuffer") then
		shader:send("rat_SortedClusterElementsBuffer", result:getSortBuffer())
	end

	love.graphics.dispatchIndirect(shader, result:getIndirectDispatchBuffer())
end

--- @private
--- @param result RatScratch.Pipeline.CullResult
function PipelineRenderer:_sort(result)
	if not self.depthSortDrawsShader:getIsReady() then
		return
	end

	local shader = self.depthSortDrawsShader:get()

	if shader:hasUniform("rat_IndirectDrawsBuffer") then
		shader:send("rat_IndirectDrawsBuffer", result:getIndirectDrawBuffer())
	end

	if shader:hasUniform("rat_DrawsBuffer") then
		shader:send("rat_DrawsBuffer", result:getDrawsBuffer())
	end

	if shader:hasUniform("rat_SortedClusterElementsBuffer") then
		shader:send("rat_SortedClusterElementsBuffer", result:getSortBuffer())
	end

	if shader:hasUniform("rat_SortedClusterElementsScratchBuffer") then
		shader:send(
			"rat_SortedClusterElementsScratchBuffer",
			result:getSortScratchBuffer()
		)
	end

	love.graphics.dispatchThreadgroups(shader, 1)
end

--- @private
--- @param result RatScratch.Pipeline.CullResult
function PipelineRenderer:_finishSort(result)
	if not self.finishDepthSortShader:getIsReady() then
		return
	end

	local shader = self.finishDepthSortShader:get()

	if shader:hasUniform("rat_IndirectDrawsBuffer") then
		shader:send("rat_IndirectDrawsBuffer", result:getIndirectDrawBuffer())
	end

	if shader:hasUniform("rat_InputDrawsBuffer") then
		shader:send("rat_InputDrawsBuffer", result:getDrawsBuffer())
	end

	if shader:hasUniform("rat_OutputDrawsBuffer") then
		shader:send("rat_OutputDrawsBuffer", result:getOtherDrawsBuffer())
	end

	if shader:hasUniform("rat_SortedClusterElementsBuffer") then
		shader:send("rat_SortedClusterElementsBuffer", result:getSortBuffer())
	end

	love.graphics.dispatchIndirect(shader, result:getIndirectDispatchBuffer())

	result:swapDrawBuffers()
end

--- @param qualityPreset string
--- @param scene RatScratch.Pipeline.Scene
--- @param result RatScratch.Pipeline.CullResult
--- @param sign -1 | 1
function PipelineRenderer:sort(qualityPreset, scene, result, sign)
	self:_prepareSortIndirect(result)
	self:_prepareSort(qualityPreset, scene, result, sign)
	self:_sort(result)
	self:_finishSort(result)
end

--- @param shader love.Shader
--- @param rendererPass RatScratch.Pipeline.RenderPass
function PipelineRenderer:bind(shader, rendererPass)
	self:_bindWorldUniforms(shader, rendererPass:getQualityPreset())
	self:_bindSceneUniforms(
		shader,
		rendererPass:getScene(),
		rendererPass:getQualityPreset()
	)
end

--- @param rendererPass RatScratch.Pipeline.RenderPass
function PipelineRenderer:draw(rendererPass)
	rendererPass:start()
	rendererPass:draw(self)
	rendererPass:stop()
end

return PipelineRenderer
