void ratApplyLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchAmbientLight light,
				   inout RatScratchPipelineLightResult result)
{
	switch (fragmentOutput.materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Vertex/ApplyLightCase.template.glsl", $RAT_SCRATCH_MATERIALS$) ***/
	default:
		ratApplyDefaultLight(fragmentOutput, light, result);
		break;
	}
}

void ratApplyLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchDirectionalLight light,
				   inout RatScratchPipelineLightResult result)
{
	switch (fragmentOutput.materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Vertex/ApplyLightCase.template.glsl", $RAT_SCRATCH_MATERIALS$) ***/
	default:
		ratApplyDefaultLight(fragmentOutput, light, result);
		break;
	}
}

void ratApplyLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchPointLight light,
				   inout RatScratchPipelineLightResult result)
{
	switch (fragmentOutput.materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Vertex/ApplyLightCase.template.glsl", $RAT_SCRATCH_MATERIALS$) ***/
	default:
		ratApplyDefaultLight(fragmentOutput, light, result);
		break;
	}
}

void ratApplyLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchSpotLight light,
				   inout RatScratchPipelineLightResult result)
{
	switch (fragmentOutput.materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Vertex/ApplyLightCase.template.glsl", $RAT_SCRATCH_MATERIALS$) ***/
	default:
		ratApplyDefaultLight(fragmentOutput, light, result);
		break;
	}
}
