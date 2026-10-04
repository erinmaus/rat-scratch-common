#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include "meshoptimizer.h"
#include "clusterlod.h"

#include <stddef.h>
#include <stdint.h>

	typedef struct RatScratchGroup
	{
		clodBounds bounds;
		int32_t lodDepth;
		uint32_t clusterIndex;
		uint32_t clusterCount;
	} RatScratchGroup;

	typedef struct RatScratchCluster
	{
		int32_t refinedIndex;

		clodBounds bounds;
		int32_t boneIndex;

		uint32_t indexOffset;
		uint32_t indexCount;
	} RatScratchCluster;

	typedef struct RatScratchNode
	{
		clodBounds bounds;
		int32_t groupIndex;

		uint32_t childIndex;
		uint32_t childCount;
	} RatScratchNode;

	typedef struct RatScratchClusterLODResult
	{
		RatScratchGroup *groups;
		size_t groupCount;

		RatScratchCluster *clusters;
		size_t clusterCount;

		RatScratchNode *nodes;
		size_t nodeCount;
		size_t rootNodeCount;

		uint32_t *indices;
		size_t indexCount;

		void *userdata;
	} RatScratchClusterLODResult;

	RAT_SCRATCH_API void rat_clusterlod_initializeConfig(struct clodConfig *config, size_t triangleCount);

	RAT_SCRATCH_API void rat_clusterlod_initializeMesh(struct clodMesh *mesh, const uint32_t *indices,
													   size_t indexCount, size_t vertexCount,
													   const float *vertexPositions, size_t vertexPositionStride,

													   const float *vertexTextureCoordinates,
													   size_t vertexTextureCoordinateStride);

	RAT_SCRATCH_API void rat_clusterlod_build(const struct clodConfig *config, const struct clodMesh *mesh,
											  size_t nodeWidth, RatScratchClusterLODResult *result);

	RAT_SCRATCH_API void rat_clusterlod_freeResult(RatScratchClusterLODResult *result);

#ifdef __cplusplus
}
#endif
