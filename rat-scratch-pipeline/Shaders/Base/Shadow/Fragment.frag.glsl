#pragma language glsl4

#include "@Pipeline/Common/Buffers/Fragment.common.glsl"
#include "@Pipeline/Common/Buffers/Materials.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"

#include "@Generated/Pipeline/Material/Properties.common.glsl"
#include "@Generated/Pipeline/Material/Fragment.common.glsl"

layout(location = 0) out vec2 rat_ShadowBufferDepth;

void pixelmain()
{
	RatScratchPipelineFragmentInput fragmentInput;
	ratGetFragmentInput(fragmentInput);

	RatScratchPipelineFragmentOutput fragmentOutput;
	ratClearFragmentOutput(fragmentOutput);
	fragmentOutput.cameraIndex = fragmentInput.cameraIndex;

#ifndef RAT_SCRATCH_FRAGMENT_DISABLE_MATERIAL
	ratFragmentApplyMaterial(fragmentInput, fragmentOutput);
#endif

#ifdef RAT_SCRATCH_FRAGMENT_ENABLE_DISCARD
	if (fragmentOutput.discardFragment != 0)
	{
		discard;
	}
#endif

	rat_ShadowBufferDepth =
		vec2(fragmentInput.worldPosition.z, fragmentInput.worldPosition.z * fragmentInput.worldPosition.z);
}
