struct RatScratchPipelineRawBVHNode
{
	float minX, minY, minZ;
	float maxX, maxY, maxZ;
	uint offset;
	uint count;
};

struct RatScratchPipelineBVHNode
{
	vec3 minBounds;
	vec3 maxBounds;
	uvec2 offsetCount;
	bool isLeaf;
};

void ratMarshalBVHNode(in RatScratchPipelineRawBVHNode inputNode, out RatScratchPipelineBVHNode outputNode)
{
	outputNode.minBounds = vec3(inputNode.minX, inputNode.minY, inputNode.minZ);
	outputNode.maxBounds = vec3(inputNode.maxX, inputNode.maxY, inputNode.maxZ);
	outputNode.offsetCount = uvec2(inputNode.offset, inputNode.count & 0x0FFFFFFF);
	outputNode.isLeaf = inputNode.count >> 31 == 1;
}
