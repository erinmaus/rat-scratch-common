#pragma language glsl4

#include "@Pipeline/Common/Buffers/Fragment.common.glsl"
#include "@Pipeline/Common/Buffers/Materials.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"

#include "@Generated/Pipeline/Material/Fragment.common.glsl"
#include "@Generated/Pipeline/Material/Properties.common.glsl"

layout(location = 0) out vec4 rat_GBufferAlbedo;	 // generally rgba8, colors
layout(location = 1) out vec4 rat_GBufferEmissive;	 // generally rgba8, emissive colors rgb, a = unused
layout(location = 2) out vec4 rat_GBufferNormal;	 // rg16f (encoded normals)
layout(location = 3) out vec4 rat_GBufferProperties; // rgba8 (metal, roughness, occlusion, unused)
layout(location = 4) out uint rat_GBufferMaterial;	 // r8 (material)

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
	rat_GBufferEmissive = vec4(fragmentOutput.emissive, fragmentOutput.albedo.a);
	rat_GBufferNormal = vec4(encodeNormal(clampNormal(fragmentOutput.normal)), 0.0, fragmentOutput.albedo.a);
	rat_GBufferProperties =
		vec4(fragmentOutput.metal, fragmentOutput.roughness, fragmentOutput.occlusion, fragmentOutput.albedo.a);
	rat_GBufferMaterial = rat_MaterialInstances[fragmentInput.materialInstance].materialDefinitionIndex;
}
