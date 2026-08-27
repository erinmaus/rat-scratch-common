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
	ambientLight.color = inputLight.color;
	ambientLight.ambience = inputLight.color.a;
	ambientLight.occlusionTextureIndexCount = inputLight.shadowTextureIndexCount;
}

void ratGetLight(in RatScratchPipelineLight inputLight, out RatScratchPipelineDirectionalLight directionalLight)
{
	directionalLight.color = inputLight.color;
	directionalLight.direction = decodeNormal(inputLight.direction);
	directionalLight.shadowTextureIndexCount = inputLight.shadowTextureIndexCount;
}

void ratGetLight(in RatScratchPipelineLight inputLight, out RatScratchPipelinePointLight pointLight)
{
	pointLight.color = inputLight.color;
	pointLight.position = inputLight.position.xyz;
	pointLight.attenuation = inputLight.attenuation.x;
	pointLight.shadowTextureIndexCount = inputLight.shadowTextureIndexCount;
}

void ratGetLight(in RatScratchPipelineLight inputLight, out RatScratchPipelineSpotLight spotLight)
{
	spotLight.color = inputLight.color;
	spotLight.position = inputLight.position.xyz;
	spotLight.direction = decodeNormal(inputLight.direction);
	spotLight.attenuation = inputLight.attenuation.x;
	spotLight.cutoff = inputLight.attenuation.y;
	spotLight.shadowTextureIndexCount = inputLight.shadowTextureIndexCount;
}

void ratClearLightResult(out RatScratchPipelineLightResult result)
{
	result.diffuse = vec4(0.0);
	result.specular = vec4(0.0);
}
