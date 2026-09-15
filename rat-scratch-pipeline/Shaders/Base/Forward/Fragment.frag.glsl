#pragma language glsl4

#include "@Pipeline/Common/Buffers/Fragment.common.glsl"

void ratDiscard(out RatScratchPipelineFragmentOutput fragmentOutput)
{
	fragmentOutput.discardFragment = 1;
}

#include "@Pipeline/Common/Buffers/Materials.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"

#include "@Generated/Pipeline/Material/Properties.common.glsl"
#include "@Generated/Pipeline/Material/Fragment.common.glsl"

#include "@Pipeline/Base/Light/ApplyLights.frag.glsl"

layout(location = 0) out vec4 rat_Color;

void pixelmain()
{
	RatScratchPipelineFragmentInput fragmentInput;
	ratGetFragmentInput(fragmentInput);

	RatScratchPipelineFragmentOutput fragmentOutput;
	ratClearFragmentOutput(fragmentOutput);
	fragmentOutput.position = fragmentInput.worldPosition;
	fragmentOutput.screenPosition = fragmentInput.screenPosition;
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
		rat_Color = vec4(fragmentOutput.albedo.rgb * result.diffuse + result.specular + result.fluorescence +
							 fragmentOutput.emissive,
						 fragmentOutput.albedo.a);
	}

	rat_Color = vec4((fragmentOutput.normal + vec3(1.0)) / vec3(2.0), 1.0);

	// TODO: OIT
}
