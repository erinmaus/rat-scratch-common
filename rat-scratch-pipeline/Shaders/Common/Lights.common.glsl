#include "@/Math/Vector.common.glsl"
#include "@Pipeline/Common/Pack.common.glsl"
#include "@Pipeline/Common/Types/Lights.common.glsl"

const uint RAT_SCRATCH_LIGHT_TYPE_AMBIENT = 0;
const uint RAT_SCRATCH_LIGHT_TYPE_DIRECTIONAL = 1;
const uint RAT_SCRATCH_LIGHT_TYPE_POINT = 2;
const uint RAT_SCRATCH_LIGHT_TYPE_SPOT = 3;

uint ratGetLightType(in RatScratchPipelineLight baseLight)
{
	if (baseLight.position.w < 0.0)
	{
		return RAT_SCRATCH_LIGHT_TYPE_AMBIENT;
	}
	else if (baseLight.position.w > 0.0)
	{
		return RAT_SCRATCH_LIGHT_TYPE_DIRECTIONAL;
	}
	else if (baseLight.attenuation.y >= 0.0)
	{
		return RAT_SCRATCH_LIGHT_TYPE_SPOT;
	}

	return RAT_SCRATCH_LIGHT_TYPE_POINT;
}

void ratGetLight(in RatScratchPipelineLight inputLight, out RatScratchPipelineAmbientLight ambientLight)
{
	ambientLight.color = vec4(inputLight.color.rgb, 1.0);
	ambientLight.ultraviolet = inputLight.color.a;
	ambientLight.ambience = inputLight.attenuation.x;
	ambientLight.occlusionTextureIndexCount = inputLight.shadowTextureIndexCount;
}

void ratGetLight(in RatScratchPipelineLight inputLight, out RatScratchPipelineDirectionalLight directionalLight)
{
	directionalLight.color = vec4(inputLight.color.rgb, 1.0);
	directionalLight.ultraviolet = inputLight.color.a;
	directionalLight.direction = decodeNormal(inputLight.direction);
	directionalLight.shadowTextureIndexCount = inputLight.shadowTextureIndexCount;
}

void ratGetLight(in RatScratchPipelineLight inputLight, out RatScratchPipelinePointLight pointLight)
{
	pointLight.color = vec4(inputLight.color.rgb, 1.0);
	pointLight.ultraviolet = inputLight.color.a;
	pointLight.position = inputLight.position.xyz;
	pointLight.attenuation = inputLight.attenuation.x;
	pointLight.shadowTextureIndexCount = inputLight.shadowTextureIndexCount;
}

void ratGetLight(in RatScratchPipelineLight inputLight, out RatScratchPipelineSpotLight spotLight)
{
	spotLight.color = vec4(inputLight.color.rgb, 1.0);
	spotLight.ultraviolet = inputLight.color.a;
	spotLight.position = inputLight.position.xyz;
	spotLight.direction = decodeNormal(inputLight.direction);
	spotLight.attenuation = inputLight.attenuation.x;
	spotLight.cutoff = inputLight.attenuation.y;
	spotLight.shadowTextureIndexCount = inputLight.shadowTextureIndexCount;
}

void ratClearLightResult(out RatScratchPipelineLightResult result)
{
	result.diffuse = vec3(0.0);
	result.specular = vec3(0.0);
	result.fluorescence = vec3(0.0);
}
