#pragma language glsl4

#include "@Pipeline/Common/Buffers/Fragment.common.glsl"

void ratDiscard(out RatScratchPipelineFragmentOutput fragmentOutput)
{
	fragmentOutput.discardFragment = 1;
}

#include "@Pipeline/Common/Buffers/Materials.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"

#include "@Generated/Pipeline/Material/Fragment.common.glsl"
#include "@Generated/Pipeline/Material/Properties.common.glsl"

#include "@Pipeline/Base/Light/ApplyLights.frag.glsl"

layout(location = 0) out vec4 rat_Color;

void pixelmain()
{
	RatScratchPipelineFragmentInput fragmentInput;
	ratGetFragmentInput(fragmentInput);

	RatScratchPipelineFragmentOutput fragmentOutput;
	ratClearFragmentOutput(fragmentOutput);
	fragmentOutput.cameraIndex = fragmentInput.cameraIndex;

	ratFragmentApplyMaterial(fragmentInput, fragmentOutput);

	if (fragmentOutput.discardFragment != 0)
	{
		rat_Color = vec4(0.0);
	}
	else
	{
		RatScratchPipelineLightResult result;
		ratClearLightResult(result);

		ratApplyLights(fragmentOutput, result);
		rat_Color = fragmentOutput.albedo * result.diffuse + vec4(fragmentOutput.emissive, 0.0);
	}

	// TODO: OIT
}
