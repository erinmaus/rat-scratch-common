#extension GL_EXT_debug_printf : enable

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

const int RAT_SCRATCH_PIPELINE_PROBE_IMPL_MAX_MIP_LEVEL =
	int(log2(float(max(RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_PROBE_SIZE_IN_PIXELS.x,
					   RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_PROBE_SIZE_IN_PIXELS.y))));

void ratSampleProbeCorrectParallaxImpl(RatScratchPipelineReflectionProbe probe, vec3 position, inout vec3 direction)
{
	vec3 probeMin = probe.position + probe.boundsMin;
	vec3 probeMax = probe.position + probe.boundsMax;

	if (!(all(greaterThanEqual(position, probeMin)) && all(lessThanEqual(position, probeMax))))
	{
		// return;
	}

	direction = normalize(direction);
	vec3 intersection1 = (probeMax - position) / direction;
	vec3 intersection2 = (probeMin - position) / direction;
	// vec3 farIntersection = max(intersection1, intersection2);
	vec3 farIntersection = mix(intersection2, intersection1, step(0.0, direction));
	float intersectionDistance = min(farIntersection.x, min(farIntersection.y, farIntersection.z));
	vec3 intersectionPosition = position + direction * intersectionDistance;

	direction = intersectionPosition - probe.position;
}

vec4 ratSampleReflectionIrradianceProbe(RatScratchPipelineReflectionProbe probe, vec3 position, vec3 direction)
{
	ratSampleProbeCorrectParallaxImpl(probe, position, direction);

	return ratSampleProbeImpl(rat_PipelineGlobalIlluminationAtlasView, probe.atlasImageIndexCount.x, direction,
							  float(RAT_SCRATCH_PIPELINE_PROBE_IMPL_MAX_MIP_LEVEL));
}

vec4 ratSampleReflectionRadianceProbe(RatScratchPipelineReflectionProbe probe, vec3 position, float roughness,
									  vec3 direction)
{
	ratSampleProbeCorrectParallaxImpl(probe, position, direction);

	const float maxMipLevel = float(RAT_SCRATCH_PIPELINE_PROBE_IMPL_MAX_MIP_LEVEL);
	float mipLevel = clamp((roughness * roughness) * maxMipLevel, 0.0, maxMipLevel);
	return ratSampleProbeImpl(rat_PipelineReflectionAtlasView, probe.atlasImageIndexCount.x, direction, mipLevel);
}

void ratRaymarchProbeImplStep(RatScratchPipelineReflectionProbe probe, vec3 worldPosition, vec3 direction,
							  inout float t, int mipLevel)
{
	vec3 currentPosition = worldPosition + direction * vec3(t);
	vec3 directionFromProbe = currentPosition - probe.position;

	uint faceOffset;
	vec2 textureCoordinate;
	ratCalculateCubeMapFaceTextureCoordinate(directionFromProbe, faceOffset, textureCoordinate);

	vec2 mipSize =
		max(vec2(ivec2(RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_PROBE_SIZE_IN_PIXELS) >> ivec2(mipLevel)), vec2(1.0));
	vec2 mipCellIndex = textureCoordinate * mipSize;

	vec2 projectedDirection = safeNormalize(vec2(dot(direction, RAT_SCRATCH_CUBE_MAP_TANGENTS[faceOffset]),
												 dot(direction, RAT_SCRATCH_CUBE_MAP_BITANGENTS[faceOffset])));

	vec2 boundaryTextureCoordinate = mix(floor(mipCellIndex), ceil(mipCellIndex), step(0.0, projectedDirection));
	boundaryTextureCoordinate /= mipSize;

	vec2 intersectionT =
		vec2(abs(projectedDirection.x) > 0 ? (boundaryTextureCoordinate.x - textureCoordinate.x) / projectedDirection.x
										   : RAT_SCRATCH_INFINITY,
			 abs(projectedDirection.y) > 0 ? (boundaryTextureCoordinate.y - textureCoordinate.y) / projectedDirection.y
										   : RAT_SCRATCH_INFINITY);

	vec2 absoluteIntersectionT = abs(intersectionT);

	vec2 projectedTextureCoordinate;
	if (all(lessThan(absoluteIntersectionT, vec2(RAT_SCRATCH_INFINITY))))
	{
		vec2 absoluteIntersectionT = abs(intersectionT);

		float projectedT;
		if (absoluteIntersectionT.x < absoluteIntersectionT.y)
		{
			projectedT = intersectionT.x;
		}
		else
		{
			projectedT = intersectionT.y;
		}

		projectedTextureCoordinate = textureCoordinate + projectedDirection * (vec2(projectedT) + vec2(0.5) / mipSize);
	}
	else
	{
		projectedTextureCoordinate = textureCoordinate;
	}

	uint projectedFaceOffset = faceOffset;
	if (!(all(greaterThanEqual(projectedTextureCoordinate, vec2(0.0))) &&
		  all(lessThanEqual(projectedTextureCoordinate, vec2(1.0)))))
	{
		vec3 remappedNormal =
			ratCalculateCubeMapNormalFromFaceTextureCoordinate(faceOffset, projectedTextureCoordinate);
		projectedFaceOffset = ratCalculateCubeMapFace(remappedNormal);

		projectedTextureCoordinate = vec2(dot(remappedNormal, RAT_SCRATCH_CUBE_MAP_TANGENTS[projectedFaceOffset]),
										  dot(remappedNormal, RAT_SCRATCH_CUBE_MAP_BITANGENTS[projectedFaceOffset]));
		projectedTextureCoordinate += vec2(1.0);
		projectedTextureCoordinate /= vec2(2.0);
	}

	uint cameraIndex = probe.atlasImageIndexCount.x + projectedFaceOffset;
	float boundaryDepthSample =
		textureLod(rat_PipelineReflectionMinMaxHiZAtlasView, vec3(projectedTextureCoordinate, cameraIndex), mipLevel).y;

	vec3 boundaryWorldPosition = ratCalculateCubeMapBoxPositionFromFaceTextureCoordinate(
		projectedFaceOffset, projectedTextureCoordinate, boundaryDepthSample, probe.position);
	float newT = dot(boundaryWorldPosition - worldPosition, direction);

	if (newT <= t)
	{
		t += RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_RAYMARCH_STEP_DISTANCE_BIAS;
	}
	else
	{
		t = newT;
	}
}

bool ratRaymarchProbeImpl(RatScratchPipelineReflectionProbe probe, vec3 worldPosition, inout vec3 direction)
{
	vec3 probeMin = probe.position + probe.boundsMin;
	vec3 probeMax = probe.position + probe.boundsMax;

	float t = RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_RAYMARCH_STEP_DISTANCE_BIAS;
	int iterations = 0;

	int mipLevel = 0;
	while (mipLevel >= 0 && mipLevel <= RAT_SCRATCH_PIPELINE_PROBE_IMPL_MAX_MIP_LEVEL &&
		   iterations <= RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_RAYMARCH_ITERATIONS)
	{
		ratRaymarchProbeImplStep(probe, worldPosition, direction, t, mipLevel);
		vec3 currentPosition = worldPosition + direction * vec3(t);
		vec3 currentDirectionFromProbe = currentPosition - probe.position;
		vec3 distanceFromProbeComponents = abs(currentDirectionFromProbe);
		float distanceFromProbe =
			max(distanceFromProbeComponents.x, max(distanceFromProbeComponents.y, distanceFromProbeComponents.z));

		vec2 minMaxDepthSample =
			ratSampleProbeImpl(rat_PipelineReflectionMinMaxHiZAtlasView, probe.atlasImageIndexCount.x,
							   currentDirectionFromProbe, float(mipLevel))
				.xy;

		if (distanceFromProbe < minMaxDepthSample.x)
		{
			++mipLevel;
		}
		else
		{
			if (distanceFromProbe > minMaxDepthSample.y)
			{
				float o = distanceFromProbe - minMaxDepthSample.y;

				t -= o;
			}

			--mipLevel;
		}

		++iterations;
	}

	if (mipLevel < 0 || true)
	{
		vec3 currentPosition = worldPosition + direction * vec3(t);
		direction = currentPosition - probe.position;

		return true;
	}

	return false;
}

bool ratRaymarchReflectionRadianceProbe(RatScratchPipelineReflectionProbe probe, vec3 position, float roughness,
										vec3 direction, out vec4 probeSample)
{
	ratRaymarchProbeImpl(probe, position, direction);

	float mipLevel = clamp((roughness * roughness) * RAT_SCRATCH_PIPELINE_PROBE_IMPL_MAX_MIP_LEVEL, 0.0,
						   RAT_SCRATCH_PIPELINE_PROBE_IMPL_MAX_MIP_LEVEL);
	probeSample =
		ratSampleProbeImpl(rat_PipelineReflectionAtlasView, probe.atlasImageIndexCount.x, direction, mipLevel);

	return true;
}

bool ratRaymarchReflectionIrradianceProbe(RatScratchPipelineReflectionProbe probe, vec3 position, vec3 direction,
										  out vec4 probeSample)
{
	ratRaymarchProbeImpl(probe, position, direction);

	probeSample = ratSampleProbeImpl(rat_PipelineReflectionAtlasView, probe.atlasImageIndexCount.x, direction);

	return true;
}
