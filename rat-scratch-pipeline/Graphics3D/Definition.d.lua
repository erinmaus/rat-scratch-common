--- @meta

--- @class RatScratch.Pipeline.Graphics3D.PipelineModelDefinition
--- @field public meshes RatScratch.Pipeline.Graphics3D.PipelineMeshDefinition[]
--- @field public transform? love.Transform
local PipelineModelDefinition = {}

--- @class RatScratch.Pipeline.Graphics3D.PipelineMeshDefinition
--- @field public vertexCount integer
--- @field public indexCount integer
--- @field public vertices table<string, love.Data>
--- @field public indices love.Data
--- @field public meshlets RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinition[]
local PipelineMeshDefinition = {}

--- @class RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinition
--- @field public indices love.Data
--- @field public staticBounds RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinitionBounds
--- @field public skinnedBounds? RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinitionSkinnedBounds[]
local PipelineMeshletDefinition = {}

--- @class RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinitionBounds
--- @field public center number[]
--- @field public radius number
local PipelineMeshletDefinitionBounds = {}

--- @class RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinitionSkinnedBounds : RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinitionBounds
--- @field public center number[]
--- @field public radius number
--- @field public bone integer
--- @field public animation integer
local PipelineMeshletDefinitionBounds = {}

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinition
--- @field public name string
--- @field public extends? string
--- @field public passes RatScratch.Pipeline.Graphics3D.PipelineMaterial.Pass[]
--- @field public features RatScratch.Pipeline.Graphics3D.PipelineMaterial.Feature[]
--- @field public shader? RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionShaderSource
--- @field public uniforms RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionUniform[]
local PipelineMaterialDefinition = {}

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionShaderSource
--- @field public vertex? string
--- @field public fragment? string
--- @field public light? string
--- @field public depth? string
local PipelineMaterialDefinitionShaderSource = {}

--- @alias RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionUniformFormat RatScratch.Graphics.Graphics3D.BufferAttributeFormat | "texture"

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionUniform
--- @field public format RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionUniformFormat
--- @field public name string
--- @field public value? number[]
local PipelineMaterialDefinitionUniform = {}
