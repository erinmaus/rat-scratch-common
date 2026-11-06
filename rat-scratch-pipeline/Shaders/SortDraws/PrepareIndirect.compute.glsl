#pragma language glsl4

#include "@Pipeline/Common/Types/Indirect.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"

layout(local_size_x = 1) in;

restrict readonly buffer rat_IndirectDrawsBuffer
{
	RatScratchPipelineIndirectDraw rat_IndirectDraws[];
};

restrict writeonly buffer rat_IndirectDispatchesBuffer
{
	RatScratchPipelineIndirectDispatch rat_IndirectDispatches[];
};

uniform uint rat_LocalThreadgroupSizeX;

void computemain()
{
	rat_IndirectDispatches[0].dispatchX =
		(rat_IndirectDraws[0].instanceCount + rat_LocalThreadgroupSizeX - 1) / rat_LocalThreadgroupSizeX;
}
