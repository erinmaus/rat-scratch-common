#pragma language glsl4

#include "@Pipeline/Radix/Common.common.glsl"
layout(local_size_x = RAT_SCRATCH_PIPELINE_WORKGROUP_SIZE) in;

#include "@Pipeline/Common/Types/Indirect.common.glsl"
#include "@Pipeline/Radix/Radix.common.glsl"
#include "./Buffers.common.glsl"

restrict readonly buffer rat_IndirectDrawsBuffer
{
	RatScratchPipelineIndirectDraw rat_IndirectDraws[];
};

shared uint rat_SharedDrawCount;

uint ratRadixGetElementCount()
{
	return rat_SharedDrawCount;
}

uint ratRadixGetResultKey(uint index)
{
	return rat_SortedClusterElements[index].depthKey;
}

uint ratRadixGetScratchKey(uint index)
{
	return rat_SortedClusterElementsScratch[index].depthKey;
}

void ratRadixSwapFromResultToScratch(uint sourceIndex, uint destinationIndex)
{
	rat_SortedClusterElementsScratch[destinationIndex] = rat_SortedClusterElements[sourceIndex];
}

void ratRadixSwapFromScratchToResult(uint sourceIndex, uint destinationIndex)
{
	rat_SortedClusterElements[destinationIndex] = rat_SortedClusterElementsScratch[sourceIndex];
}

void computemain()
{
	if (gl_LocalInvocationID.x == 0)
	{
		rat_SharedDrawCount = rat_IndirectDraws[0].instanceCount;
	}

	barrier();

	ratRadixSort();
}
