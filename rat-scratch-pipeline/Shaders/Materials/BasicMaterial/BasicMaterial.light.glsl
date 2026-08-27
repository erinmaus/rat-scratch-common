#include "@Pipeline/Base/Light/DefaultApplyLights.frag.glsl"

void ratApplyFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
						   in RatScratchPipelineAmbientLight ambientLight, inout RatScratchPipelineLightResult result)
{
	ratApplyDefaultFragmentLight(fragmentOutput, ambientLight, result);
}

void ratApplyFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
						   in RatScratchPipelineDirectionalLight directionalLight,
						   inout RatScratchPipelineLightResult result)
{
	ratApplyDefaultFragmentLight(fragmentOutput, directionalLight, result);
}

void ratApplyFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
						   in RatScratchPipelinePointLight pointLight, inout RatScratchPipelineLightResult result)
{
	ratApplyDefaultFragmentLight(fragmentOutput, pointLight, result);
}

void ratApplyFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchPipelineSpotLight spotLight,
						   inout RatScratchPipelineLightResult result)
{
	ratApplyDefaultFragmentLight(fragmentOutput, spotLight, result);
}
