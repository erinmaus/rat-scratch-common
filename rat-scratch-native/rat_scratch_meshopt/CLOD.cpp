#include <cstring>
#include <vector>
#include <stack>
#include <unordered_map>
#include <tuple>

#include "meshoptimizer.h"
#define CLUSTERLOD_IMPLEMENTATION
#include "clusterlod.h"

#include "../rat_scratch_native_common/RatScratch.h"
#include "CLOD.h"

struct RatScratchClusterLODResultData
{
	std::vector<uint32_t> indices;
	std::vector<RatScratchGroup> groups;
	std::vector<RatScratchCluster> clusters;
	std::vector<RatScratchNode> nodes;
};

extern "C" RAT_SCRATCH_API void rat_clusterlod_initializeConfig(struct clodConfig *config, size_t triangleCount)
{
	*config = clodDefaultConfig(triangleCount);

	config->min_triangles = triangleCount;
	config->max_vertices = triangleCount * 3;
}

static const float VERTEX_ATTRIBUTE_WEIGHTS_WITH_TEXTURE_COORDINATES[] = {0.5f, 0.5f};

extern "C" RAT_SCRATCH_API void rat_clusterlod_initializeMesh(struct clodMesh *mesh, const uint32_t *indices,
															  size_t indexCount, size_t vertexCount,
															  const float *vertexPositions, size_t vertexPositionStride,
															  const float *vertexTextureCoordinates,
															  size_t vertexTextureCoordinateStride)
{
	std::memset(mesh, 0, sizeof(clodMesh));

	mesh->indices = indices;
	mesh->index_count = indexCount;
	mesh->vertex_count = vertexCount;
	mesh->vertex_positions = vertexPositions;
	mesh->vertex_positions_stride = vertexPositionStride;
	mesh->vertex_attributes = vertexTextureCoordinates;
	mesh->vertex_attributes_stride = vertexTextureCoordinateStride;

	if (vertexTextureCoordinates)
	{
		mesh->attribute_weights = VERTEX_ATTRIBUTE_WEIGHTS_WITH_TEXTURE_COORDINATES;
		mesh->attribute_count = 1;
		mesh->attribute_protect_mask = (1 << 0) | (1 << 1);
	}
}

extern "C" RAT_SCRATCH_API void rat_clusterlod_build(const struct clodConfig *config, const struct clodMesh *mesh,
													 size_t nodeWidth, RatScratchClusterLODResult *result)
{
	std::vector<clodGroup> groups;
	std::vector<std::vector<uint32_t>> clusterIndices;
	std::vector<clodCluster> groupClusters;
	std::vector<std::tuple<uint32_t, uint32_t>> groupClusterIndexCounts;

	clodBuild(*config, *mesh, [&](clodGroup group, const clodCluster *clusters, size_t clusterCount) -> int {
		groups.push_back(group);

		auto clusterIndex = groupClusters.size();
		for (size_t i = 0; i < clusterCount; ++i)
		{
			auto &inputCluster = clusters[i];

			clusterIndices.emplace_back(inputCluster.indices, inputCluster.indices + inputCluster.index_count);
			auto &indices = clusterIndices.back();

			clodCluster outputCluster = inputCluster;
			outputCluster.indices = indices.data();

			groupClusters.emplace_back(std::move(outputCluster));
		}

		groupClusterIndexCounts.emplace_back(clusterIndex, clusterCount);

		return (int32_t)(groups.size()) - 1;
	});

	auto levels = (size_t)(groups.back().depth) + 1;
	std::vector<clodNode> nodes(clodBuildHierarchyBound(groups.size(), nodeWidth, levels));

	size_t nodeCount = clodBuildHierarchy(nodes.data(), groups.data(), groups.size(), nodeWidth, levels);
	nodes.resize(nodeCount);

	memset(result, 0, sizeof(RatScratchClusterLODResult));

	auto userdata = new RatScratchClusterLODResultData();
	result->userdata = userdata;

	for (size_t i = 0; i < groups.size(); ++i)
	{
		auto &inputGroup = groups.at(i);
		auto clusterIndexCount = groupClusterIndexCounts.at(i);

		auto clusterIndex = std::get<0>(clusterIndexCount);
		auto clusterCount = std::get<1>(clusterIndexCount);

		RatScratchGroup outputGroup = {};
		outputGroup.bounds = inputGroup.simplified;
		outputGroup.lodDepth = inputGroup.depth;
		outputGroup.clusterIndex = clusterIndex;
		outputGroup.clusterCount = clusterCount;

		userdata->groups.push_back(outputGroup);
	}

	for (size_t i = 0; i < groupClusters.size(); ++i)
	{
		auto &inputCluster = groupClusters.at(i);

		auto offset = userdata->indices.size();
		userdata->indices.resize(offset + inputCluster.index_count);
		std::memcpy(userdata->indices.data() + offset, inputCluster.indices,
					inputCluster.index_count * sizeof(uint32_t));

		RatScratchCluster outputCluster = {};
		outputCluster.refinedIndex = inputCluster.refined;
		outputCluster.bounds = inputCluster.bounds;
		outputCluster.indexOffset = offset;
		outputCluster.indexCount = inputCluster.index_count;

		userdata->clusters.push_back(outputCluster);
	}

	for (size_t i = 0; i < nodes.size(); ++i)
	{
		auto &inputNode = nodes.at(i);

		RatScratchNode outputNode = {};
		outputNode.bounds = inputNode.bounds;
		outputNode.groupIndex = inputNode.group;
		outputNode.childIndex = inputNode.child_offset;
		outputNode.childCount = inputNode.child_count;

		userdata->nodes.push_back(outputNode);
	}

	result->groups = userdata->groups.data();
	result->groupCount = userdata->groups.size();
	result->clusters = userdata->clusters.data();
	result->clusterCount = userdata->clusters.size();
	result->nodes = userdata->nodes.data();
	result->nodeCount = userdata->nodes.size();
	result->rootNodeCount = levels;
	result->indices = userdata->indices.data();
	result->indexCount = userdata->indices.size();
}

extern "C" RAT_SCRATCH_API void rat_clusterlod_freeResult(RatScratchClusterLODResult *result)
{
	RatScratchClusterLODResultData *userdata = (RatScratchClusterLODResultData *)result->userdata;
	delete userdata;

	std::memset(result, 0, sizeof(RatScratchClusterLODResult));
}
