#pragma language glsl4

#include "./Buffers.common.glsl"

layout(local_size_x = 64) in;

#include "@Pipeline/Common/Types/Indirect.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"

restrict readonly buffer rat_InputDrawsBuffer
{
	RatScratchPipelineDraw rat_InputDraws[];
};

restrict writeonly buffer rat_OutputDrawsBuffer
{
	RatScratchPipelineDraw rat_OutputDraws[];
};

restrict readonly buffer rat_IndirectDrawsBuffer
{
	RatScratchPipelineIndirectDraw rat_IndirectDraws[];
};

shared uint rat_SharedDrawCount;

void computemain()
{
	if (gl_LocalInvocationID.x == 0)
	{
		rat_SharedDrawCount = rat_IndirectDraws[0].instanceCount;
	}

	barrier();

	uint destinationIndex = gl_GlobalInvocationID.x;
	if (destinationIndex >= rat_SharedDrawCount)
	{
		return;
	}

	uint sourceIndex = rat_SortedClusterElements[destinationIndex].drawIndex;
	rat_OutputDraws[destinationIndex] = rat_InputDraws[sourceIndex];
}
