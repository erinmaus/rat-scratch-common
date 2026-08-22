#define ratApplyFragmentMaterial ratApply$RAT_SCRATCH_MATERIAL$FragmentMaterialImpl

#include "$RAT_SCRATCH_MATERIAL_SHADER_SOURCE_PATH$"

const uint RAT_SCRATCH_MATERIAL_TYPE_$RAT_SCRATCH_MATERIAL$ = RAT_SCRATCH_MATERIAL_DEFINITION_INDEX$;

void ratApply$RAT_SCRATCH_MATERIAL$FragmentMaterial(in RatScratchPipelineVertexInput fragmentInput,
													out RatScratchVertexOutput fragmentOutput)
{
	ratApply$RAT_SCRATCH_PARENT_MATERIAL$FragmentMaterial(fragmentInput, fragmentOutput);
	ratApply$RAT_SCRATCH_MATERIAL$FragmentMaterialImpl(fragmentInput, fragmentOutput);
}

#undef ratApplyFragmentMaterial
