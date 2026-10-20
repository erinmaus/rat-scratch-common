#include "@Pipeline/Common/Buffers/ReflectionProbe.common.glsl"
#include "@/Math/Common.common.glsl"
#include "@/Common/CubeMap.common.glsl"

vec4 ratSampleProbeImpl(sampler2DArray atlasTexture, uint layer, vec3 direction, float level)
{
	uint offset;
	vec2 textureCoordinate;
	ratCalculateCubeMapFaceTextureCoordinate(direction, offset, textureCoordinate);

	return textureLod(atlasTexture, vec3(textureCoordinate, layer + offset), level);
}

vec4 ratSampleProbeImpl(sampler2DArray atlasTexture, uint layer, vec3 direction)
{
	uint offset;
	vec2 textureCoordinate;
	ratCalculateCubeMapFaceTextureCoordinate(direction, offset, textureCoordinate);

	return texture(atlasTexture, vec3(textureCoordinate, layer + offset));
}

const float RAT_SCRATCH_PIPELINE_PROBE_IMPL_MIP_OFFSET =
	log2(float(max(RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_PROBE_SIZE_IN_PIXELS.x,
				   RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_PROBE_SIZE_IN_PIXELS.y)) *
		 sqrt(3.0));
const float RAT_SCRATCH_PIPELINE_PROBE_IMPL_MAX_MIP_LEVEL =
	log2(float(RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_PROBE_SIZE_IN_PIXELS));

void ratSampleProbeCorrectParallaxImpl(RatScratchPipelineReflectionProbe probe, vec3 position, inout vec3 direction)
{
	vec3 probeMin = probe.position - vec3(probe.radius.x);
	vec3 probeMax = probe.position + vec3(probe.radius.x);

	if (!(all(greaterThanEqual(position, probeMin)) && all(lessThanEqual(position, probeMax))))
	{
		return;
	}

	vec3 offset = position - probe.position;
	float distanceFromProbe = length(offset);
	if (distanceFromProbe < RAT_SCRATCH_EPSILON || distanceFromProbe < probe.radius.x)
	{
		return;
	}

	vec3 perpendicularOffset = offset - vec3(dot(offset, direction)) * direction;
	direction = normalize(direction + perpendicularOffset / vec3(probe.radius.x));
}

vec4 ratSampleGlobalIlluminationProbe(RatScratchPipelineReflectionProbe probe, vec3 position, vec3 direction)
{
	//ratSampleProbeCorrectParallaxImpl(probe, position, direction);
	return ratSampleProbeImpl(rat_PipelineGlobalIlluminationAtlasView, probe.atlasImageIndexCount.x, direction);
}

vec4 ratSampleReflectionProbe(RatScratchPipelineReflectionProbe probe, vec3 position, float roughness, vec3 direction)
{
	//ratSampleProbeCorrectParallaxImpl(probe, position, direction);

	roughness = max(roughness, 0.01);
	float s = 2.0 / (roughness * roughness) - 2.0;
	float mipLevel = clamp(RAT_SCRATCH_PIPELINE_PROBE_IMPL_MIP_OFFSET - 0.5 * log2(s + 1.0), 0.0,
						   RAT_SCRATCH_PIPELINE_PROBE_IMPL_MAX_MIP_LEVEL);

	return ratSampleProbeImpl(rat_PipelineReflectionAtlasView, probe.atlasImageIndexCount.x, direction, mipLevel);
}
