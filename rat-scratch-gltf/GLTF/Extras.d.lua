--- @class RatScratch.GLTF.Extra.RAT_asset_original
--- @field public asset RatScratch.GLTF.Asset
local RATAssetOriginal = {}

--- @alias RatScratch.GLTF.Extra.RAT_extras_serialize.SerializeFunc fun<T>(self: T, builder: RatScratch.GLTF.GLTFBuilder, object: RatScratch.GLTF.Object, index: integer, definition: RatScratch.Graphics.Graphics3D.Definition) | fun(builder: RatScratch.GLTF.GLTFBuilder, object: RatScratch.GLTF.Object, index: integer, definition: RatScratch.Graphics.Graphics3D.Definition)

--- @class RatScratch.GLTF.Extra.RAT_extras_serialize
--- @field public userdata any
--- @field public serialize RatScratch.GLTF.Extra.RAT_extras_serialize.SerializeFunc
local RATExtrasSerialize = {}

return {
	RAT_asset_original = RATAssetOriginal,
	RAT_extras_serialize = RATExtrasSerialize,
}
