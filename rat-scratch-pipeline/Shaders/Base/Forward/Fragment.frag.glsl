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

#include "./OIT.frag.glsl"

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
		return;
	}

	RatScratchPipelineLightResult result;
	ratClearLightResult(result);
	result.occlusion = fragmentOutput.occlusion;

	ratApplyLights(fragmentOutput, result);
	vec4 color = vec4(fragmentOutput.albedo.rgb * result.diffuse + result.specular + result.fluorescence +
						  fragmentOutput.emissive,
					  fragmentOutput.albedo.a);
	ratForwardOITWrite(ivec3(gl_FragCoord.xy, fragmentOutput.cameraIndex), color, fragmentOutput.screenPosition.z);
}
