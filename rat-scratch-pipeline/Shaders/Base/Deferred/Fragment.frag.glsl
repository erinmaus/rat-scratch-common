#pragma language glsl4

#include "@Pipeline/Common/Buffers/Fragment.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"

#include "generated://Pipeline/Material/Fragment.common.glsl"
#include "generated://Pipeline/Material/Properties.common.glsl"

layout(location = 0) out vec4 rat_GBufferAlbedo;	 // generally rgba8, colors
layout(location = 1) out vec4 rat_GBufferEmissive;	 // generally rgba8, emissive colors rgb, a = unused
layout(location = 2) out vec4 rat_GBufferNormal;	 // rg16f (encoded normals)
layout(location = 3) out vec4 rat_GBufferProperties; // rgba8 (metal, roughness, occlusion, unused)
layout(location = 4) out int rat_GBufferMaterial;	 // r8 (material)

void pixelmain()
{
	RatScratchPipelineFragmentInput fragmentInput;
	ratGetFragmentInput(fragmentInput);

	RatScratchPipelineFragmentOutput fragmentOutput;
	ratClearFragmentOutput(fragmentOutput);
	fragmentOutput.cameraIndex = fragmentInput.cameraIndex;

	ratFragmentApplyMaterial(fragmentInput, fragmentOutput);

	rat_GBufferAlbedo = fragmentOutput.albedo;
	rat_GBufferEmissive = vec4(fragmentOutput.emissive, fragmentOutput.albedo.a);
	rat_GBufferNormal = encodeNormal(clampNormal(fragmentOutput.normal));
	rat_GBufferProperties =
		vec4(fragmentOutput.metal, fragmentOutput.roughness, fragmentOutput.occlusion, fragmentOutput.albedo.a);
	rat_GBufferMaterial = rat_MaterialInstances[fragmentInput.materialInstance].materialDefinitionIndex;
}
