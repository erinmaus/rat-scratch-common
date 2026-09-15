#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include "../rat_scratch_native_common/RatScratch.h"
#include "meshoptimizer.h"
#include <stddef.h>
#include <stdint.h>

	RAT_SCRATCH_API void rat_meshopt_computeMeshletBounds(const unsigned int *meshletVertices,
														  const unsigned char *meshletTriangles, size_t triangleCount,
														  float *vertexPositions, size_t vertexCount,
														  size_t vertexPositionsStride, struct meshopt_Bounds *bounds);

#ifdef __cplusplus
}
#endif
