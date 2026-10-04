#pragma language glsl4

#include "@Pipeline/Common/Buffers/Fragment.common.glsl"
#include "@Pipeline/Common/Buffers/Materials.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"

#include "@Generated/Pipeline/Material/Properties.common.glsl"
#include "@Generated/Pipeline/Material/Fragment.common.glsl"

// See ./rat-scratch-pipeline/GBuffer.lua
layout(location = 0) out vec4 rat_GBufferAlbedo;
layout(location = 1) out vec4 rat_GBufferEmissive;
layout(location = 2) out vec4 rat_GBufferFluorescence;
layout(location = 3) out vec4 rat_GBufferNormal;
layout(location = 4) out vec4 rat_GBufferProperties;

void pixelmain()
{
	RatScratchPipelineFragmentInput fragmentInput;
	ratGetFragmentInput(fragmentInput);

	RatScratchPipelineFragmentOutput fragmentOutput;
	ratClearFragmentOutput(fragmentOutput);
	fragmentOutput.cameraIndex = fragmentInput.cameraIndex;

#ifndef RAT_SCRATCH_FRAGMENT_DISABLE_MATERIAL
	ratFragmentApplyMaterial(fragmentInput, fragmentOutput);
#endif

#ifdef RAT_SCRATCH_FRAGMENT_ENABLE_DISCARD
	if (fragmentOutput.discardFragment != 0)
	{
		discard;
	}
#endif

	rat_GBufferAlbedo = fragmentOutput.albedo;
	rat_GBufferEmissive = vec4(fragmentOutput.emissive, fragmentOutput.heat);
	rat_GBufferFluorescence = vec4(fragmentOutput.fluorescence, fragmentOutput.albedo.a);
	rat_GBufferNormal = vec4(encodeNormal(clampNormal(fragmentOutput.normal)), 0.0, fragmentOutput.albedo.a);
	rat_GBufferProperties =
		vec4(fragmentOutput.metal, fragmentOutput.roughness, fragmentOutput.occlusion,
			 float(rat_MaterialInstances[fragmentInput.materialInstance].materialDefinitionIndex) / 255.0);
}
