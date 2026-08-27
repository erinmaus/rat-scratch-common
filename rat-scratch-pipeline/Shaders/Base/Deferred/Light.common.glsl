#include "@Pipeline/Base/Light/ApplyLights.frag.glsl"
#include "@Pipeline/Common/Buffers/Fragment.common.glsl"
#include "@Pipeline/Common/Camera.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"

varying ratTextureCoordinateType frag_TextureCoordinate;

uniform ratGBufferSamplerBufferType rat_GBufferDepthTexture;
uniform ratGBufferSamplerBufferType rat_GBufferAlbedoTexture;
uniform ratGBufferSamplerBufferType rat_GBufferEmissiveTexture;
uniform ratGBufferSamplerBufferType rat_GBufferNormalTexture;
uniform ratGBufferSamplerBufferType rat_GBufferPropertiesTexture;
uniform uratGBufferSamplerBufferType rat_GBufferMaterialTexture;

layout(location = 0) out vec4 rat_Result;

void pixelmain()
{
	vec2 textureCoordinate = frag_TextureCoordinate;
	float depth = texture(rat_GBufferDepthTexture, textureCoordinate).x;
	vec4 albedo = texture(rat_GBufferAlbedoTexture, textureCoordinate);
	vec3 emissive = texture(rat_GBufferEmissiveTexture, textureCoordinate).rgb;
	vec3 normal = decodeNormal(texture(rat_GBufferNormalTexture, textureCoordinate).xy);
	vec3 materialProperties = texture(rat_GBufferPropertiesTexture, textureCoordinate).xyz;
	uint materialDefinitionIndex = texture(rat_GBufferMaterialTexture, textureCoordinate).x;

	RatScratchPipelineFragmentOutput fragmentOutput;
	ratClearFragmentOutput(fragmentOutput);

	fragmentOutput.screenPosition = vec3(textureCoordinate, depth);
	fragmentOutput.position = ratScreenPositionToWorldPosition(fragmentOutput.screenPosition, 0);
	fragmentOutput.albedo = albedo;
	fragmentOutput.emissive = emissive;
	fragmentOutput.normal = normal;
	fragmentOutput.metal = materialProperties.x;
	fragmentOutput.roughness = materialProperties.y;
	fragmentOutput.occlusion = materialProperties.z;
	fragmentOutput.materialDefinitionIndex = materialDefinitionIndex;
	fragmentOutput.cameraIndex = RAT_CAMERA_INDEX;

	RatScratchPipelineLightResult result;
	ratClearLightResult(result);

	ratApplyLights(fragmentOutput, result);
	rat_Result = albedo * result.diffuse + vec4(emissive, 0.0);
}

#pragma option RAT_SCRATCH_FRAGMENT_SKIP_VARYINGS
