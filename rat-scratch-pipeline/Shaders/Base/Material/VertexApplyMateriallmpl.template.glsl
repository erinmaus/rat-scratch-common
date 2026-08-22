#define ratApplyVertexMaterial ratApply$RAT_SCRATCH_MATERIAL$VertexMaterialImpl

#include "$RAT_SCRATCH_MATERIAL_SHADER_SOURCE_PATH$"

const uint RAT_SCRATCH_MATERIAL_TYPE_$RAT_SCRATCH_MATERIAL$ = RAT_SCRATCH_MATERIAL_DEFINITION_INDEX$;

void ratApply$RAT_SCRATCH_MATERIAL$VertexMaterial(in RatScratchPipelineDraw draw,
												  out RatScratchPipelineFragmentInput fragmentInput)
{
	ratApply$RAT_SCRATCH_PARENT_MATERIAL$VertexMaterial(draw, fragmentInput);
	ratApply$RAT_SCRATCH_MATERIAL$VertexMaterialImpl(draw, fragmentInput);
}

#undef ratApplyVertexMaterial
