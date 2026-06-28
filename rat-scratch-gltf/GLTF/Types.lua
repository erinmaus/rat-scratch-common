--- @class RatScratch.GLTF.Object
--- @field public extension? table
--- @field public extras? table | number | string | boolean
local Object = {}

--- @class RatScratch.GLTF.NamedObject : RatScratch.GLTF.Object
--- @field public name? string
local NamedObject = {}

--- @enum RatScratch.GLTF.AccessorComponentType
local AccessorComponentType = {
	BYTE = 5120,
	UNSIGNED_BYTE = 5121,
	SHORT = 5122,
	UNSIGNED_SHORT = 5123,
	UNSIGNED_INT = 5125,
	FLOAT = 5126,
}

--- @alias RatScratch.GLTF.AccessorElementType "SCALAR" | "VEC2" | "VEC3" | "VEC4" | "MAT2" | "MAT3" | "MAT4"

--- @class RatScratch.GLTF.Accessor : RatScratch.GLTF.NamedObject
--- @field public bufferView? integer
--- @field public byteOffset? integer
--- @field public componentType RatScratch.GLTF.AccessorComponentType
--- @field public normalized? boolean
--- @field public count integer
--- @field public type RatScratch.GLTF.AccessorElementType
--- @field public sparse? RatScratch.GLTF.SparseAccessor
--- @field public max? number[]
--- @field public min? number[]
local Accessor = {}

--- @class RatScratch.GLTF.SparseAccessor : RatScratch.GLTF.Object
--- @field public count integer
--- @field public indices RatScratch.GLTF.SparseAccessorIndices
--- @field public values RatScratch.GLTF.SparseAccessorValues
local SparseAccessor = {}

--- @enum RatScratch.GLTF.SparseAccessorIndicesComponentType
local SparseAccessorIndicesComponentType = {
	UNSIGNED_BYTE = 5121,
	UNSIGNED_SHORT = 5123,
	UNSIGNED_INT = 5125,
}

--- @class RatScratch.GLTF.SparseAccessorIndices : RatScratch.GLTF.Object
--- @field public bufferView integer
--- @field public byteOffset? integer
--- @field public componentType RatScratch.GLTF.SparseAccessorIndicesComponentType
local SparseAccessorIndices = {}

--- @class RatScratch.GLTF.SparseAccessorValues : RatScratch.GLTF.Object
--- @field public bufferView integer
--- @field public byteOffset? integer
local SparseAccessorValues = {}

--- @class RatScratch.GLTF.Animation : RatScratch.GLTF.NamedObject
--- @field public channels RatScratch.GLTF.AnimationChannel[]
--- @field public samplers RatScratch.GLTF.AnimationChannelSampler[]
local Animation = {}

--- @class RatScratch.GLTF.AnimationChannel : RatScratch.GLTF.Object
--- @field public sampler integer
--- @field public target RatScratch.GLTF.AnimationChannelTarget
local AnimationChannel = {}

--- @alias RatScratch.GLTF.AnimationChannelTargetPath "weights" | "translation" | "rotation" | "scale"

--- @class RatScratch.GLTF.AnimationChannelTarget : RatScratch.GLTF.Object
--- @field public node integer
--- @field public path RatScratch.GLTF.AnimationChannelTargetPath
local AnimationChannelTarget = {}

--- @alias RatScratch.GLTF.AnimationChannelSamplerInterpolation "STEP" | "LINEAR" | "CUBICSPLINE"

--- @class RatScratch.GLTF.AnimationChannelSampler : RatScratch.GLTF.Object
--- @field public input integer
--- @field public interpolation RatScratch.GLTF.AnimationChannelSamplerInterpolation
--- @field public output integer
local AnimationChannelSampler = {}

--- @class RatScratch.GLTF.Asset : RatScratch.GLTF.Object
--- @field public copyright string
--- @field public generator string
--- @field public version string
--- @field public minVersion string
local Asset = {}

--- @class RatScratch.GLTF.Buffer : RatScratch.GLTF.NamedObject
--- @field public uri string
--- @field public byteLength integer
local Buffer = {}

--- @enum RatScratch.GLTF.BufferViewTarget
local BufferViewTarget = {
	ARRAY_BUFFER = 34962,
	ELEMENT_ARRAY_BUFFER = 34963,
}

--- @class RatScratch.GLTF.BufferView : RatScratch.GLTF.NamedObject
--- @field public buffer integer
--- @field public byteOffset? integer
--- @field public byteLength integer
--- @field public byteStride integer
--- @field public target RatScratch.GLTF.BufferViewTarget
local BufferView = {}

--- @alias RatScratch.GLTF.Camera RatScratch.GLTF.PerspectiveCamera | RatScratch.GLTF.OrthographicCamera

--- @class RatScratch.GLTF.OrthographicCamera : RatScratch.GLTF.NamedObject
--- @field public orthographic RatScratch.GLTF.OrthographicCameraProperties
--- @field public type "orthographic"
local OrthographicCamera = {}

--- @class RatScratch.GLTF.OrthographicCameraProperties : RatScratch.GLTF.Object
--- @field public xmag number
--- @field public ymag number
--- @field public znear number
--- @field public zfar number
local OrthographicCameraProperties = {}

--- @class RatScratch.GLTF.PerspectiveCamera : RatScratch.GLTF.NamedObject
--- @field public type "perspective"
local PerspectiveCamera = {}

--- @class RatScratch.GLTF.PerspectiveCameraProperties : RatScratch.GLTF.Object
--- @field public aspectRatio? number
--- @field public yfov number
--- @field public zfar number
--- @field public znear number
local PerspectiveCameraProperties = {}

--- @class RatScratch.GLTF.GLTF : RatScratch.GLTF.Object
--- @field public extensions? string[]
--- @field public extensionsRequired? string[]
--- @field public accessors? RatScratch.GLTF.Accessor[]
--- @field public animations? RatScratch.GLTF.Animation[]
--- @field public asset RatScratch.GLTF.Asset
--- @field public buffers? RatScratch.GLTF.Buffer[]
--- @field public bufferViews? RatScratch.GLTF.BufferView[]
--- @field public cameras? RatScratch.GLTF.Camera[]
--- @field public images? RatScratch.GLTF.Image[]
--- @field public materials? RatScratch.GLTF.Material[]
--- @field public meshes? RatScratch.GLTF.Mesh[]
--- @field public nodes? RatScratch.GLTF.Node[]
--- @field public samplers? RatScratch.GLTF.Sampler[]
--- @field public skins? RatScratch.GLTF.Skin[]
--- @field public scenes? RatScratch.GLTF.Scene[]
--- @field public textures? RatScratch.GLTF.Texture[]
local GLTF = {}

--- @class RatScratch.GLTF.Image : RatScratch.GLTF.NamedObject
--- @field public uri? string
--- @field public mimeType? string
--- @field public bufferView? integer
local Image = {}

--- @alias RatScratch.GLTF.MaterialAlphaMode "OPAQUE" | "MASK" | "BLEND"

--- @class RatScratch.GLTF.Material : RatScratch.GLTF.NamedObject
--- @field public pbrMetallicRoughness? RatScratch.GLTF.MaterialPBRMetallicRoughness
--- @field public normalTextureInfo? RatScratch.GLTF.MaterialNormalTextureInfo
--- @field public occlusionTextureInfo? RatScratch.GLTF.MaterialOcclusionTextureInfo
--- @field public emissiveTexture? RatScratch.GLTF.TextureInfo
--- @field public emissiveFactor? number[]
--- @field public alphaMode? RatScratch.GLTF.MaterialAlphaMode
--- @field public alphaCutoff? number
--- @field public doubleSided? boolean
local Material = {}

--- @class RatScratch.GLTF.MaterialPBRMetallicRoughness : RatScratch.GLTF.Object
--- @field public baseColorFactor? number[]
--- @field public baseColorTexture? RatScratch.GLTF.TextureInfo
--- @field public metallicFactor? number
--- @field public roughnessFactor? number
--- @field public metallicRoughnessTexture? RatScratch.GLTF.TextureInfo
local MaterialPBRMetallicRoughness = {}

--- @class RatScratch.GLTF.MaterialNormalTextureInfo : RatScratch.GLTF.Object
--- @field public index integer
--- @field public texCoord? integer
--- @field public scale? number
local MaterialNormalTextureInfo = {}

--- @class RatScratch.GLTF.MaterialOcclusionTextureInfo : RatScratch.GLTF.Object
--- @field public index integer
--- @field public texCoord? integer
--- @field public strength? number
local MaterialOcclusionTextureInfo = {}

--- @class RatScratch.GLTF.Mesh : RatScratch.GLTF.NamedObject
--- @field public primitives RatScratch.GLTF.MeshPrimitive[]
--- @field public weights? number[]
local Mesh = {}

--- @enum RatScratch.GLTF.MeshPrimitiveMode
local MeshPrimitiveMode = {
	POINTS = 0,
	LINES = 1,
	LINE_LOOP = 2,
	LINE_STRIP = 3,
	TRIANGLES = 4,
	TRIANGLE_STRIP = 5,
	TRIANGLE_FAN = 6,
}

--- @alias RatScratch.GLTF.MeshPrimitiveMorphTarget "POSITION" | "NORMAL" | "TANGENT"

--- @class RatScratch.GLTF.MeshPrimitive : RatScratch.GLTF.NamedObject
--- @field public attributes table<string, integer>
--- @field public indices? number
--- @field public material? number
--- @field public mode RatScratch.GLTF.MeshPrimitiveMode
--- @field public targets table<RatScratch.GLTF.MeshPrimitiveMorphTarget, integer>
local MeshPrimitive = {}

--- @class RatScratch.GLTF.Node : RatScratch.GLTF.NamedObject
--- @field public camera? number?
--- @field public children? number[]
--- @field public skin number
--- @field public matrix? number[]
--- @field public mesh? number
--- @field public rotation? number[]
--- @field public scale? number[]
--- @field public translation? number[]
--- @field public weights? number[]
local Node = {}

--- @enum RatScratch.GLTF.SamplerMagFilter
local SamplerMagFilter = {
	NEAREST = 9728,
	LINEAR = 9729,
}

--- @enum RatScratch.GLTF.SamplerMinFilter
local SamplerMinFilter = {
	NEAREST = 9728,
	LINEAR = 9729,
	NEAREST_MIPMAP_NEAREST = 9984,
	LINEAR_MIPMAP_NEAREST = 9985,
	NEAREST_MIPMAP_LINEAR = 9986,
	LINEAR_MIPMAP_LINEAR = 9987,
}

--- @enum RatScratch.GLTF.SamplerWrap
local SamplerWrap = {
	CLAMP_TO_EDGE = 33071,
	MIRRORED_REPEAT = 33648,
	REPEAT = 10497,
}

--- @class RatScratch.GLTF.Sampler : RatScratch.GLTF.NamedObject
--- @field public magFilter? RatScratch.GLTF.SamplerMagFilter
--- @field public minFilter? RatScratch.GLTF.SamplerMinFilter
--- @field public wrapS? RatScratch.GLTF.SamplerWrap
--- @field public wrapT? RatScratch.GLTF.SamplerWrap
local Sampler = {}

--- @class RatScratch.GLTF.Scene : RatScratch.GLTF.NamedObject
--- @field public nodes? number[]
local Scene = {}

--- @class RatScratch.GLTF.Skin : RatScratch.GLTF.NamedObject
--- @field public inverseBindMatrices? number
--- @field public skeleton? number
--- @field public joints integer[]
local Skin = {}

--- @class RatScratch.GLTF.Texture : RatScratch.GLTF.Object
--- @field public sampler? integer
--- @field public source? integer
local Texture = {}

--- @class RatScratch.GLTF.TextureInfo : RatScratch.GLTF.Object
--- @field public index integer
--- @field public texCoord integer
local TextureInfo = {}

--- @enum RatScratch.GLTF.GLBChunkTypes
local GLBChunkTypes = {
	[0x4E4F534A] = "json",
	[0x004E4942] = "bin",
	json = 0x4E4F534A,
	bin = 0x004E4942,
}

return {
	Object = Object,
	NamedObject = NamedObject,
	AccessorComponentType = AccessorComponentType,
	Accessor = Accessor,
	SparseAccessor = SparseAccessor,
	SparseAccessorIndicesComponentType = SparseAccessorIndicesComponentType,
	SparseAccessorIndices = SparseAccessorIndices,
	SparseAccessorValues = SparseAccessorValues,
	Animation = Animation,
	AnimationChannel = AnimationChannel,
	AnimationChannelTarget = AnimationChannelTarget,
	AnimationChannelSampler = AnimationChannelSampler,
	Asset = Asset,
	Buffer = Buffer,
	BufferViewTarget = BufferViewTarget,
	BufferView = BufferView,
	OrthographicCamera = OrthographicCamera,
	OrthographicCameraProperties = OrthographicCameraProperties,
	PerspectiveCamera = PerspectiveCamera,
	PerspectiveCameraProperties = PerspectiveCameraProperties,
	GLTF = GLTF,
	Image = Image,
	Material = Material,
	MaterialPBRMetallicRoughness = MaterialPBRMetallicRoughness,
	MaterialNormalTextureInfo = MaterialNormalTextureInfo,
	MaterialOcclusionTextureInfo = MaterialOcclusionTextureInfo,
	Mesh = Mesh,
	MeshPrimitiveMode = MeshPrimitiveMode,
	MeshPrimitive = MeshPrimitive,
	Node = Node,
	SamplerMagFilter = SamplerMagFilter,
	SamplerMinFilter = SamplerMinFilter,
	SamplerWrap = SamplerWrap,
	Sampler = Sampler,
	Scene = Scene,
	Skin = Skin,
	Texture = Texture,
	TextureInfo = TextureInfo,

	GLB_VERSION = 2,
	GLTF_VERSION = "2.0",
	GLBChunkTypes = GLBChunkTypes,
}
