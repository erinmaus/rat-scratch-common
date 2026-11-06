#include "./Types.common.glsl"

restrict buffer rat_SortedClusterElementsBuffer
{
	RatScratchPipelineSortedCluster rat_SortedClusterElements[];
};

restrict buffer rat_SortedClusterElementsScratchBuffer
{
	RatScratchPipelineSortedCluster rat_SortedClusterElementsScratch[];
};
