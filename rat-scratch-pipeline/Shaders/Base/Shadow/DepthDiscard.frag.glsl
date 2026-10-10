#define RAT_SCRATCH_FRAGMENT_ENABLE_DISCARD

#include "@Pipeline/Common/Buffers/Fragment.common.glsl"

void ratDiscard(out RatScratchPipelineFragmentOutput fragmentOutput)
{
	fragmentOutput.discardFragment = 1;
}

#include "@Pipeline/Base/Shadow/Fragment.frag.glsl"
