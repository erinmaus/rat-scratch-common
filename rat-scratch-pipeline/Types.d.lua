--- @meta

--- @class RatScratch.Pipeline.PipelineDefinition
--- @field public pipeline RatScratch.Pipeline.PipelineDefinitionConfig
local PipelineDefinition = {}

--- @class RatScratch.Pipeline.PipelineDefinitionConfig
--- @field public version string
--- @field public meshletFormat RatScratch.Pipeline.PipelineDefinitionMeshleftFormat
--- @field public vertexBuffers RatScratch.Pipeline.PipelineDefinitionVertexBuffer[]
--- @field public indexBuffer RatScratch.Pipeline.PipelineDefinitionIndexBuffer
local PipelineDefinitionConfig = {}

--- @class RatScratch.Pipeline.PipelineDefinitionMeshleftFormat
--- @field public triangleCount integer
local PipelineDefinitionMeshleftFormat = {}

--- @alias RatScratch.Pipeline.PipelineDefinitionVertexBufferRole
--- | "static"
--- | "skinned"

--- @class RatScratch.Pipeline.PipelineDefinitionVertexBuffer
--- @field public role RatScratch.Pipeline.PipelineDefinitionVertexBufferRole
--- @field public buffer string
--- @field public format RatScratch.Pipeline.PipelineDefinitionVertexBufferAttribute[]
local PipelineDefinitionVertexBuffer = {}

--- @class RatScratch.Pipeline.PipelineDefinitionVertexBufferAttribute
--- @field public role string
--- @field public name string
--- @field public buffer string
--- @field public inputFormat RatScratch.Graphics.Graphics3D.BufferAttributeFormat
--- @field public vertexFormat RatScratch.Graphics.Graphics3D.BufferAttributeFormat
--- @field public transform? RatScratch.Pipeline.PipelineDefinitionVertexBufferAttributeTransform
local PipelineDefinitionVertexBufferAttribute = {}

--- @class RatScratch.Pipeline.PipelineDefinitionVertexBufferAttributeTransform
--- @field public from string
--- @field public to string
local PipelineDefinitionVertexBufferAttributeTransform = {}

--- @class RatScratch.Pipeline.PipelineDefinitionIndexBuffer
--- @field public name string
--- @field public buffer string
--- @field public format RatScratch.Graphics.Graphics3D.BufferAttributeFormat
local PipelineDefinitionIndexBuffer = {}

--- @class RatScratch.Pipeline.PipelineRuntime
--- @field public pipeline RatScratch.Pipeline.PipelineRuntimeConfig
local PipelineRuntime = {}

--- @class RatScratch.Pipeline.PipelineRuntimeConfig
--- @field public main RatScratch.Pipeline.PipelineRuntimeConfigVariable[]
--- @field public secondary? RatScratch.Pipeline.PipelineRuntimeConfigVariable[]
local PipelineRuntimeConfig = {}

--- @class RatScratch.Pipeline.PipelineRuntimeConfigVariable
--- @field public name string
--- @field public format RatScratch.Graphics.Graphics3D.BufferFormat
--- @field public value number[]
local PipelineRuntimeConfigVariable = {}
