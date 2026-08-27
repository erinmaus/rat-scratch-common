#define ratApplyFragmentMaterial ratApply$RAT_SCRATCH_MATERIAL$FragmentMaterialImpl

#include "$RAT_SCRATCH_FRAGMENT_SHADER_SOURCE$"

void ratApply$RAT_SCRATCH_MATERIAL$FragmentMaterial(in RatScratchPipelineFragmentInput fragmentInput,
													out RatScratchPipelineFragmentOutput fragmentOutput)
{
	ratApply$RAT_SCRATCH_PARENT_MATERIAL$FragmentMaterial(fragmentInput, fragmentOutput);
	ratApply$RAT_SCRATCH_MATERIAL$FragmentMaterialImpl(fragmentInput, fragmentOutput);
}

#undef ratApplyFragmentMaterial
