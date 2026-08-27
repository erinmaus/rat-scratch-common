
void ratApplyNoneVertexMaterial(in RatScratchPipelineDraw draw, out RatScratchPipelineFragmentInput fragmentInput)
{
	// Nothing
}

/*** $("@Pipeline/Base/Material/VertexApplyMaterialImpl.template.glsl", $RAT_SCRATCH_VERTEX_MATERIALS$) ***/

void ratVertexApplyMaterial(in RatScratchPipelineDraw draw, out RatScratchPipelineFragmentInput fragmentInput)
{
	uint materialDefinitionIndex = rat_MaterialInstances[fragmentInput.materialInstance].materialDefinitionIndex;
	switch (materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Material/VertexApplyMaterialCase.template.glsl", $RAT_SCRATCH_VERTEX_MATERIALS$) ***/
	default:
		ratApplyNoneVertexMaterial(draw, fragmentInput);
		break;
	}
}
