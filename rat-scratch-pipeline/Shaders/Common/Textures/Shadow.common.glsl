#include "@/Common/CubeMap.common.glsl"
#include "@/Math/Common.common.glsl"
#include "@/Math/Vector.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Shadows.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"
#include "@Pipeline/Common/Types/Shadows.common.glsl"
#include "@Pipeline/Common/Camera.common.glsl"

float ratShadowTextureImplSampleCompareDepth(vec2 moments, float fragmentDepth)
{
	float mean = moments.x;
	float secondMoment = moments.y;

	if (fragmentDepth >= mean)
	{
		return 1.0;
	}

	float variance = secondMoment - (mean * mean);
	float difference = fragmentDepth - mean;

	variance = max(variance, RAT_SCRATCH_EPSILON);
	return variance / (variance + difference * difference);
}

bool ratSampleShadowImplGetTextureSpaceCoordinate(uint cameraIndex, vec3 worldPosition, out vec3 lightTexturePosition)
{
	vec4 position = vec4(worldPosition, 1.0);
	vec4 lightViewPosition = rat_ShadowCameras[cameraIndex].viewTransform * position;
	vec4 lightProjectedPosition = rat_ShadowCameras[cameraIndex].projectionTransform * lightViewPosition;
	lightProjectedPosition.xyz /= lightProjectedPosition.w;

	lightTexturePosition = vec3(lightProjectedPosition.xy * vec2(0.5) + vec2(0.5), lightViewPosition.z);

	float minXYZ = min(lightProjectedPosition.x, min(lightProjectedPosition.y, lightProjectedPosition.z));
	float maxXYZ = max(lightProjectedPosition.x, max(lightProjectedPosition.y, lightProjectedPosition.z));

	return !(minXYZ < -1.0 || maxXYZ > 1.0);
}

float ratSampleShadowTextureDirect(sampler2DArray atlasTexture, uint shadowTextureIndex, vec3 textureSpacePosition)
{
	textureSpacePosition.xy = clamp(textureSpacePosition.xy, vec2(0.0), vec2(1.0));
	textureSpacePosition.xy = vec2(1.0) - textureSpacePosition.xy;

	RatScratchPipelineShadowTexture textureAtlasInfo = rat_ShadowTextures[shadowTextureIndex];
	vec2 atlasTextureCoordinate = textureSpacePosition.xy * textureAtlasInfo.size + textureAtlasInfo.position;

	vec2 moments = texture(atlasTexture, vec3(atlasTextureCoordinate, textureAtlasInfo.layer)).rg;
	return ratShadowTextureImplSampleCompareDepth(moments, textureSpacePosition.z);
}

float ratSampleShadowImplGetViewZ(uint cameraIndex, vec3 worldPosition)
{
	vec4 position = vec4(worldPosition, 1.0);
	vec4 lightViewPosition = rat_ShadowCameras[cameraIndex].viewTransform * position;
	float near = ratGetCameraZNear(rat_ShadowCameras[cameraIndex]);
	float far = ratGetCameraZFar(rat_ShadowCameras[cameraIndex]);
	return (lightViewPosition.z - near) / (far - near);
}

float ratSampleCubeShadowTexture(uvec2 shadowTextureIndex, vec3 worldPosition, vec3 lightPosition)
{
	if (shadowTextureIndex.y == 0)
	{
		return 1.0;
	}

	vec3 lightToSurface = lightPosition - worldPosition;

	uint i;
	vec3 textureCoordinate;
	ratCalculateCubeMapFaceTextureCoordinate(lightToSurface, i, textureCoordinate.xy);
	uint currentShadowTextureIndex = shadowTextureIndex.x + i;
	uint cameraIndex = rat_ShadowTextures[currentShadowTextureIndex].cameraIndex;
	textureCoordinate.z = ratSampleShadowImplGetViewZ(cameraIndex, worldPosition);
	float shadow =
		ratSampleShadowTextureDirect(rat_PipelineShadowTextureAtlasView, currentShadowTextureIndex, textureCoordinate);

	return shadow;
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

	return ratSampleShadowTextureDirect(rat_PipelineShadowTextureAtlasView, shadowTextureIndex.x, lightTexturePosition);
}
