void ratApplyLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchPipelineAmbientLight light,
				   inout RatScratchPipelineLightResult result)
{
	switch (fragmentOutput.materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Light/ApplyLightCase.template.glsl", $RAT_SCRATCH_LIGHT_MATERIALS$) ***/
	default:
		ratApplyDefaultFragmentLight(fragmentOutput, light, result);
		break;
	}
}

void ratApplyLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchPipelineDirectionalLight light,
				   inout RatScratchPipelineLightResult result)
{
	switch (fragmentOutput.materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Light/ApplyLightCase.template.glsl", $RAT_SCRATCH_LIGHT_MATERIALS$) ***/
	default:
		ratApplyDefaultFragmentLight(fragmentOutput, light, result);
		break;
	}
}

void ratApplyLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchPipelinePointLight light,
				   inout RatScratchPipelineLightResult result)
{
	switch (fragmentOutput.materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Light/ApplyLightCase.template.glsl", $RAT_SCRATCH_LIGHT_MATERIALS$) ***/
	default:
		ratApplyDefaultFragmentLight(fragmentOutput, light, result);
		break;
	}
}

void ratApplyLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchPipelineSpotLight light,
				   inout RatScratchPipelineLightResult result)
{
	switch (fragmentOutput.materialDefinitionIndex)
	{
	/*** $("@Pipeline/Base/Light/ApplyLightCase.template.glsl", $RAT_SCRATCH_LIGHT_MATERIALS$) ***/
	default:
		ratApplyDefaultFragmentLight(fragmentOutput, light, result);
		break;
	}
}
