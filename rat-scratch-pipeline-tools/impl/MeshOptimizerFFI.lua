local PATH = ...
local ffi = require("ffi")
local Object = require("rat-scratch-common").Object
local RatScratchModule = require("lib.rat-scratch-module")
local Vector3 = require("rat-scratch-math").Vector3

--- @class RatScratch.Pipeline.impl.MeshOptimizerFFI : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Pipeline.impl.MeshOptimizerFFI
local MeshOptimizerFFI = Object()

--- @class RatScratch.Pipeline.impl.MeshOptimizerFFI.Bounds
--- @field public position RatScratch.Math.Vector3
--- @field public radius number
local MeshOptimizerFFIBounds = {}

--- @private
MeshOptimizerFFI._IS_INTIALIZED = false

--- @param indexData love.ByteData
--- @param indexCount integer
--- @param vertexData love.ByteData
--- @param vertexCount integer
--- @param vertexFormat RatScratch.Graphics.Graphics3D.BufferFormat
--- @param maxVertices integer
--- @param minTriangles integer
--- @param maxTriangles integer
--- @param coneWeight number
--- @param splitFactor number
--- @return love.ByteData[], RatScratch.Pipeline.impl.MeshOptimizerFFI.Bounds[]
function MeshOptimizerFFI.buildMeshletsFlex(
	indexData,
	indexCount,
	vertexData,
	vertexCount,
	vertexFormat,
	maxVertices,
	minTriangles,
	maxTriangles,
	coneWeight,
	splitFactor
)
	local indexDataPointer =
		ffi.cast("unsigned int *", indexData:getFFIPointer())

	local vertexDataPointer = ffi.cast(
		"float *",
		ffi.cast("uint8_t *", vertexData:getFFIPointer())
			+ vertexFormat:getByteOffset("VertexPosition")
	)

	local meshletVertices = ffi.new("uint32_t[?]", indexCount)
	local meshletTriangles = ffi.new("uint8_t[?]", indexCount)

	local meshoptimizer, ratMeshoptimizer = MeshOptimizerFFI.load()
	local maxMeshletCount = meshoptimizer.meshopt_buildMeshletsBound(
		indexCount,
		maxVertices,
		minTriangles
	)
	local meshlets = ffi.new("struct meshopt_Meshlet[?]", maxMeshletCount)

	local meshletCount = tonumber(
		meshoptimizer.meshopt_buildMeshletsFlex(
			meshlets,
			meshletVertices,
			meshletTriangles,
			indexDataPointer,
			indexCount,
			vertexDataPointer,
			vertexCount,
			vertexFormat:getStride(),
			maxVertices,
			minTriangles,
			maxTriangles,
			coneWeight,
			splitFactor
		)
	)

	local indexBuffers = {}
	local bounds = {}

	local boundsStruct = ffi.new("struct meshopt_Bounds[1]")
	for i = 1, meshletCount do
		local m = meshlets[i - 1]

		local indexBuffer =
			love.data.newByteData(m.triangle_count * 3 * ffi.sizeof("uint32_t"))
		local indexBufferPointer =
			ffi.cast("uint32_t *", indexBuffer:getFFIPointer())

		for j = 1, m.triangle_count do
			local k = (j - 1) * 3

			local l1 = meshletTriangles[m.triangle_offset + k]
			local l2 = meshletTriangles[m.triangle_offset + k + 1]
			local l3 = meshletTriangles[m.triangle_offset + k + 2]

			local g1 = meshletVertices[m.vertex_offset + l1]
			local g2 = meshletVertices[m.vertex_offset + l2]
			local g3 = meshletVertices[m.vertex_offset + l3]

			indexBufferPointer[k] = g1
			indexBufferPointer[k + 1] = g2
			indexBufferPointer[k + 2] = g3
		end

		table.insert(indexBuffers, indexBuffer)

		ratMeshoptimizer.rat_meshopt_computeMeshletBounds(
			meshletVertices + m.vertex_offset,
			meshletTriangles + m.triangle_offset,
			m.triangle_count,
			vertexDataPointer,
			vertexCount,
			vertexFormat:getStride(),
			boundsStruct
		)

		table.insert(bounds, {
			position = Vector3(
				boundsStruct[0].center[0],
				boundsStruct[0].center[1],
				boundsStruct[0].center[2]
			),
			radius = boundsStruct[0].radius,
		})
	end

	return indexBuffers, bounds
end

function MeshOptimizerFFI.load()
	if MeshOptimizerFFI._IS_INTIALIZED then
		return unpack(MeshOptimizerFFI._LIBRARY)
	end

	ffi.cdef([[
		struct meshopt_Meshlet
		{
			unsigned int vertex_offset;
			unsigned int triangle_offset;

			unsigned int vertex_count;
			unsigned int triangle_count;
		};

		struct meshopt_Bounds
		{
			float center[3];
			float radius;

			float cone_apex[3];
			float cone_axis[3];
			float cone_cutoff;

			signed char cone_axis_s8[3];
			signed char cone_cutoff_s8;
		};

		size_t meshopt_buildMeshletsFlex(
			struct meshopt_Meshlet *meshlets,
			unsigned int *vertices,
			unsigned char *meshlet_triangles,
			const unsigned int *indices,
			size_t index_count,
			const float *vertex_positions,
			size_t vertex_count,
			size_t vertex_positions_stride,
			size_t max_vertices,
			size_t min_triangles,
			size_t max_triangles,
			float cone_weight,
			float split_factor);
		
			size_t meshopt_buildMeshletsBound(size_t index_count, size_t max_vertices, size_t max_triangles);
		
		void rat_meshopt_computeMeshletBounds(
			const unsigned int *meshletVertices,
			const unsigned char *meshletTriangles,
			size_t triangleCount,
			float *vertexPositions,
			size_t vertexCount,
			size_t vertexPositionsStride,
			struct meshopt_Bounds *bounds
		);
	]])

	MeshOptimizerFFI._LIBRARY = {
		RatScratchModule.loadLibrary(PATH, "libmeshoptimizer"),
		RatScratchModule.loadLibrary(PATH, "rat_scratch_meshopt"),
	}
	MeshOptimizerFFI._IS_INTIALIZED = true

	return unpack(MeshOptimizerFFI._LIBRARY)
end

return MeshOptimizerFFI
