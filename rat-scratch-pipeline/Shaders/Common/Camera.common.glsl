#include "@Pipeline/Buffers/Draw.common.glsl"
#include "@Pipeline/Types/Draw.common.glsl"

vec3 ratScreenPositionToWorldPosition(vec3 screenPosition, uint cameraIndex)
{
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];

	vec4 clipSpacePosition = vec4(screenPosition * vec3(2.0) - vec3(1.0);, 1.0);
	vec4 viewSpacePosition = camera.inverseProjectionTransform * clipSpacePosition;
	viewSpacePosition /= vec4(viewSpacePosition.w);

	vec4 worldSpacePosition = camera.inverseProjectionTransform * viewSpacePosition;
	return worldSpacePosition.xyz;
}
