struct RatScratchPipelineSortedCluster
{
	uint depthKey;
	float depthValue;
	uint drawIndex;
};

uint depthToDepthKey(float depth)
{
	uint depthKey = floatBitsToUint(depth);
	if (depth < 0.0)
	{
		return ~depthKey;
	}
	return depthKey | 0x80000000;
}
