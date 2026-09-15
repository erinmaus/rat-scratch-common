#include "@/Common/CubeMap.common.glsl"
#include "@/Math/Common.common.glsl"
#include "@/Math/Vector.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Shadows.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"
#include "@Pipeline/Common/Types/Shadows.common.glsl"

float ratShadowTextureImplSampleCompareDepth(vec2 moments, float fragmentDepth)
{
	float mean = moments.x;
	float secondMoment = moments.y;

	if (fragmentDepth <= mean)
	{
		return 1.0;
	}

	float variance = secondMoment - (mean * mean);
	float difference = fragmentDepth - mean;

	variance = max(variance, RAT_SCRATCH_EPSILON);

	return variance / (variance + difference * difference);
}

float ratShadowTextureImplCalculateWeight(vec3 textureSpacePosition, vec3 lightToSurface, vec3 direction)
{
	float d = dot(lightToSurface, direction);
	if (d >= -0.5)
	{
		return 0.0;
	}

	vec2 diff = abs(textureSpacePosition.xy - vec2(0.5));
	float maxDiff = max(diff.x, diff.y);
	return max(0.0, 0.5 - maxDiff);
}

float ratSampleShadowTextureDirect(sampler2DArray atlasTexture, uint shadowTextureIndex, vec3 textureSpacePosition)
{
	RatScratchPipelineShadowTexture textureAtlasInfo = rat_PipelineShadowTextures[shadowTextureIndex];
	vec2 atlasTextureCoordinate = textureSpacePosition.xy * textureAtlasInfo.size + textureAtlasInfo.position;

	vec2 moments = texture(atlasTexture, vec3(atlasTextureCoordinate, textureAtlasInfo.layer)).rg;
	return ratShadowTextureImplSampleCompareDepth(moments, textureSpacePosition.z);
}

bool ratSampleShadowImplGetTextureSpaceCoordinate(uint cameraIndex, vec3 worldPosition, out vec3 lightTexturePosition)
{
	vec4 position = vec4(worldPosition, 1.0);
	vec4 lightViewPosition = rat_Cameras[cameraIndex].viewTransform * position;
	vec4 lightProjectedPosition = rat_Cameras[cameraIndex].projectionTransform * lightViewPosition;
	lightProjectedPosition.xyz /= lightProjectedPosition.w;

	lightTexturePosition = vec3(lightProjectedPosition.xy * vec2(0.5) + vec2(0.5), lightViewPosition.z);

	float minXYZ = min(lightProjectedPosition.x, min(lightProjectedPosition.y, lightProjectedPosition.z));
	float maxXYZ = max(lightProjectedPosition.x, max(lightProjectedPosition.y, lightProjectedPosition.z));

	return !(minXYZ < -1.0 || maxXYZ > 1.0);
}

float ratSampleCubeShadowTexture(uvec2 shadowTextureIndex, vec3 worldPosition, vec3 lightPosition)
{
	vec4 position = vec4(worldPosition, 1.0);
	vec3 lightToSurface = safeNormalize(lightPosition - worldPosition);

	float weight = 0.0;
	float shadow = 0.0;

	/* We just assume count (shadowTextureIndex.y) equals RAT_SCRATCH_CUBE_MAP_FACES (6) so we can try and unroll the
	 * loop. */
	for (uint i = 0; i < RAT_SCRATCH_CUBE_MAP_FACES; ++i)
	{
		uint currentShadowTextureIndex = shadowTextureIndex.x + i;
		uint cameraIndex = rat_ShadowTextures[currentShadowTextureIndex].cameraIndex;

		vec3 lightTexturePosition;
		if (ratSampleShadowImplGetTextureSpaceCoordinate(cameraIndex, worldPosition, lightTexturePosition))
		{
			float w =
				ratShadowTextureImplCalculateWeight(lightTexturePosition, lightToSurface, RAT_CUBE_MAP_NORMALS[i]);
			if (w > 0.0)
			{
				weight += w;
				shadow += ratSampleShadowTextureDirect(rat_PipelineShadowTextureAtlasView, lightTexturePosition);
			}
		}
	}

	if (weight < RAT_SCRATCH_EPSILON)
	{
		return 1.0;
	}

	return shadow / weight;
}

float ratSampleShadowTexture(uvec2 shadowTextureIndex, vec3 worldPosition)
{
	if (shadowTextureIndex.y == 0)
	{
		return 1.0;
	}

	uint cameraIndex = rat_ShadowTextures[shadowTextureIndex.x].cameraIndex;

	vec3 lightTexturePosition;
	if (!ratSampleShadowImplGetTextureSpaceCoordinate(cameraIndex, worldPosition, lightTexturePosition))
	{
		return 1.0;
	}

	return ratSampleShadowTextureDirect(rat_PipelineShadowTextureAtlasView, shadowTextureIndex, lightTexturePosition);
}
