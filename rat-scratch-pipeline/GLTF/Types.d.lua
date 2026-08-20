--- @meta

--- @class RatScratch.Pipeline.GLTF.RAT_pipeline_extra : RatScratch.Pipeline.PipelineDefinition
local RATPipelineExtra = {}

--- @class RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets
--- @field public vertexCount integer
--- @field public indexCount integer
--- @field public attributes table<string, integer>
--- @field public indices integer
--- @field public meshlets RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets.PrimitiveMeshlet[]
--- @field public material? RatScratch.Pipeline.GLTF.RATMaterial
local RATMeshMeshletPrimitive = {}

--- @class RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets.Bounds
--- @field public center number[]
--- @field public radius number

--- @class RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets.SkinnedBounds : RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets.Bounds
--- @field public animation integer
--- @field public bone integer

--- @class RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets.PrimitiveMeshlet
--- @field public indices integer
--- @field public staticBounds RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets.Bounds
--- @field public skinnedBounds? RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets.SkinnedBounds[]
local RATMeshMeshletPrimitiveMeshlets = {}

--- @class RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets.VertexAttributeBufferInfo
--- @field public pipelineBuffer string
--- @field public bufferView integer
local RATMeshMeshletVertexAttributeBufferInfo = {}

--- @class RatScratch.Pipeline.GLTF.RATMaterial
--- @field public name string
--- @field public fields table<string, RatScratch.Pipeline.GLTF.RATMaterialField>
local RATMaterial = {}

--- @alias RatScratch.Pipeline.GLTF.RATMaterialField
--- | number[]
--- | RatScratch.Pipeline.GLTF.RATMaterialTextureField

--- @class RatScratch.Pipeline.GLTF.RATMaterialTextureField
--- @field public texture integer
local RATMaterialTextureField = {}
