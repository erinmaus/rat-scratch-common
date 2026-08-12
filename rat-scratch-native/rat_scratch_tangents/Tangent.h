#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include "../rat_scratch_native_common/RatScratch.h"
#include <stddef.h>
#include <stdint.h>

	typedef struct RatScratchVertexAttribute
	{
		float *value;
		size_t stride;
	} RatScratchVertexAttribute;

	typedef struct RatScratchInputVertexInfo
	{
		RatScratchVertexAttribute position;
		RatScratchVertexAttribute normal;
		RatScratchVertexAttribute textureCoordinate;
	} RatScratchInputVertexInfo;

	typedef struct RatScratchOutputVertexInfo
	{
		RatScratchVertexAttribute tangent;
	} RatScratchOutputVertexInfo;

	typedef struct RatScratchIndexInfo
	{
		uint32_t *indices;
		size_t count;
	} RatScratchIndexInfo;

	typedef struct RatScratchTangentUserdata
	{
		RatScratchInputVertexInfo inputVertexInfo;
		RatScratchOutputVertexInfo outputVertexInfo;
		RatScratchIndexInfo indexInfo;
	} RatScratchTangentUserdata;

	RAT_SCRATCH_API int rat_generateTangents(uint32_t *indices, size_t indexCount, float *position,
											 size_t positionStride, float *normal, size_t normalStride,
											 float *textureCoordinate, size_t textureCoordinateStride, float *tangent,
											 size_t tangentStride);

#ifdef __cplusplus
}
#endif
