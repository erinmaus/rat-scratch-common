#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"

vec3 ratGetCameraPosition(uint cameraIndex)
{
	return rat_Cameras[cameraIndex].inverseViewTransform[3].xyz;
}

float ratGetCameraErrorFactor(uint cameraIndex)
{
	return abs(rat_Cameras[cameraIndex].projectionTransform[1][1]) / 2.0;
}

float ratGetCameraZNear(uint cameraIndex)
{
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];
	return camera.projectionTransform[2][3] / (camera.projectionTransform[2][2] - 1.0);
}

float ratGetCameraZFar(uint cameraIndex)
{
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];
	return camera.projectionTransform[2][3] / (camera.projectionTransform[2][2] + 1.0);
}

vec3 ratGetCameraPosition(RatScratchPipelineCamera camera)
{
	return camera.inverseViewTransform[3].xyz;
}

float ratGetCameraErrorFactor(RatScratchPipelineCamera camera)
{
	return abs(camera.projectionTransform[1][1]) / 2.0;
}

float ratGetCameraZNear(RatScratchPipelineCamera camera)
{
	return camera.projectionTransform[2][3] / (camera.projectionTransform[2][2] - 1.0);
}

float ratGetCameraZFar(RatScratchPipelineCamera camera)
{
	return camera.projectionTransform[2][3] / (camera.projectionTransform[2][2] + 1.0);
}

vec3 ratScreenPositionToWorldPosition(vec3 screenPosition, uint cameraIndex)
{
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];

	vec4 clipSpacePosition = vec4(screenPosition * vec3(2.0) - vec3(1.0), 1.0);
	vec4 viewSpacePosition = camera.inverseProjectionTransform * clipSpacePosition;
	viewSpacePosition /= vec4(viewSpacePosition.w);

	vec4 worldSpacePosition = camera.inverseViewTransform * viewSpacePosition;
	return worldSpacePosition.xyz;
}
