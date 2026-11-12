#pragma language glsl4

#include "@Pipeline/Common/Buffers/Fragment.common.glsl"

#include "@Pipeline/Common/Buffers/Materials.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"

#include "@Generated/Pipeline/Material/Properties.common.glsl"
#include "@Generated/Pipeline/Material/Fragment.common.glsl"

#include "@Pipeline/Base/Light/ApplyLights.frag.glsl"

#include "./OIT.frag.glsl"

#ifdef RAT_SCRATCH_PIPELINE_FORWARD_SORTED
layout(location = 0) out vec4 out_Color;
#endif

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
#ifdef RAT_SCRATCH_PIPELINE_FORWARD_SORTED
#ifdef RAT_SCRATCH_PIPELINE_FORWARD_MASKED
		discard;
#else
		out_Color = vec4(0.0);
#endif
#endif
		return;
	}

	RatScratchPipelineLightResult result;
	ratClearLightResult(result);
	result.occlusion = fragmentOutput.occlusion;

	ratApplyLights(fragmentOutput, result);
	vec4 color = vec4(fragmentOutput.albedo.rgb * result.diffuse + result.specular + result.fluorescence +
						  fragmentOutput.emissive,
					  fragmentOutput.albedo.a);

#ifdef RAT_SCRATCH_PIPELINE_FORWARD_OIT
	ratForwardOITWrite(ivec3(gl_FragCoord.xy, fragmentOutput.cameraIndex), color, fragmentOutput.screenPosition.z);
#endif

#ifdef RAT_SCRATCH_PIPELINE_FORWARD_SORTED
#ifdef RAT_SCRATCH_PIPELINE_FORWARD_MASKED
	out_Color = vec4(color.rgb, 1.0);
#else
	out_Color = color;
#endif
#endif
}
