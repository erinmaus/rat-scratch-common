#define RAT_SCRATCH_FRAGMENT_ENABLE_DISCARD

void ratDiscard(out RatScratchPipelineFragmentOutput fragmentOutput)
{
	fragmentOutput.discardFragment = true;
}

#include "@Pipeline/Base/Deferred/Fragment.frag.glsl"
