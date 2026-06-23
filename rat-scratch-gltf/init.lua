local GLTF = require("rat-scratch-gltf.GLTF.GLTF")

return {
	loadFromFilesystem = GLTF.loadFromFilesystem,
	loadFromFile = GLTF.loadFromFile,

	Accessor = require("rat-scratch-gltf.GLTF.Accessor"),
	Attributes = require("rat-scratch-gltf.GLTF.Attributes"),
	Parser = require("rat-scratch-gltf.GLTF.Parser"),
	SparseAccessor = require("rat-scratch-gltf.GLTF.SparseAccessor"),
	Types = require("rat-scratch-gltf.GLTF.Types"),
}
