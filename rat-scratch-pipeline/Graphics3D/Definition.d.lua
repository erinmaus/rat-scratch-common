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
