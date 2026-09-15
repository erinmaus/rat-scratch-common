#include "Main.h"
#include "../rat_scratch_native_common/RatScratch.h"
#include "membership.h"

RAT_SCRATCH_API void rat_meshopt_computeMeshletBounds(const unsigned int *meshletVertices,
													  const unsigned char *meshletTriangles, size_t triangleCount,
													  float *vertexPositions, size_t vertexCount,
													  size_t vertexPositionsStride, struct meshopt_Bounds *bounds)
{
	*bounds = meshopt_computeMeshletBounds(meshletVertices, meshletTriangles, triangleCount, vertexPositions,
										   vertexCount, vertexPositionsStride);
}
