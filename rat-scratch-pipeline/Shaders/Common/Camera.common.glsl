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
	return camera.projectionTransform[3][2] / (camera.projectionTransform[2][2] - 1.0);
}

float ratGetCameraZFar(uint cameraIndex)
{
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];
	return camera.projectionTransform[3][2] / (camera.projectionTransform[2][2] + 1.0);
}

vec3 ratScreenPositionToWorldPosition(uint cameraIndex, vec3 screenPosition)
{
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];

	vec4 clipSpacePosition = vec4(screenPosition * vec3(2.0) - vec3(1.0), 1.0);
	vec4 viewSpacePosition = camera.inverseProjectionTransform * clipSpacePosition;
	viewSpacePosition /= vec4(viewSpacePosition.w);

	vec4 worldSpacePosition = camera.inverseViewTransform * viewSpacePosition;
	return worldSpacePosition.xyz;
}

vec3 ratScreenPositionToViewPosition(uint cameraIndex, vec3 screenPosition)
{
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];

	vec4 clipSpacePosition = vec4(screenPosition * vec3(2.0) - vec3(1.0), 1.0);
	vec4 viewSpacePosition = camera.inverseProjectionTransform * clipSpacePosition;
	viewSpacePosition /= vec4(viewSpacePosition.w);

	return viewSpacePosition.xyz;
}

float ratLinearizeDepth(uint cameraIndex, float depth)
{
	float near = ratGetCameraZNear(cameraIndex);
	float far = ratGetCameraZFar(cameraIndex);

	float ndcDepth = 2.0 * depth - 1.0;
	float linearDepth = 2.0 * near * far / (far + near - ndcDepth * (far - near));

	return linearDepth;
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
	return camera.projectionTransform[3][2] / (camera.projectionTransform[2][2] - 1.0);
}

float ratGetCameraZFar(RatScratchPipelineCamera camera)
{
	return camera.projectionTransform[3][2] / (camera.projectionTransform[2][2] + 1.0);
}

float ratLinearizeDepth(RatScratchPipelineCamera camera, float depth)
{
	float near = ratGetCameraZNear(camera);
	float far = ratGetCameraZFar(camera);

	float ndcDepth = 2.0 * depth - 1.0;
	float linearDepth = 2.0 * near * far / (far + near - ndcDepth * (far - near));

	return linearDepth;
}

vec3 ratScreenPositionToWorldPosition(RatScratchPipelineCamera camera, vec3 screenPosition)
{
	vec4 clipSpacePosition = vec4(screenPosition * vec3(2.0) - vec3(1.0), 1.0);
	vec4 viewSpacePosition = camera.inverseProjectionTransform * clipSpacePosition;
	viewSpacePosition /= vec4(viewSpacePosition.w);

	vec4 worldSpacePosition = camera.inverseViewTransform * viewSpacePosition;
	return worldSpacePosition.xyz;
}

vec3 ratScreenPositionToViewPosition(RatScratchPipelineCamera camera, vec3 screenPosition)
{
	vec4 clipSpacePosition = vec4(screenPosition * vec3(2.0) - vec3(1.0), 1.0);
	vec4 viewSpacePosition = camera.inverseProjectionTransform * clipSpacePosition;
	viewSpacePosition /= vec4(viewSpacePosition.w);

	return viewSpacePosition.xyz;
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
