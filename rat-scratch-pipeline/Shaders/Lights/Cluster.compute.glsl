layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

#include "@Generated/Pipeline/Config.common.glsl"
#include "@/Math/Common.common.glsl"
#include "@/Math/Vector.common.glsl"
#include "@Pipeline/Common/Lights.common.glsl"
#include "@Pipeline/Common/Types/Lights.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"

restrict readonly buffer rat_LightsBuffer
{
	RatScratchPipelineLight rat_Lights[];
};

restrict buffer rat_LightCountIndicesBuffer
{
	uint rat_LightCountIndices[];
};

restrict readonly buffer rat_ActiveCamerasBuffer
{
	uint rat_ActiveCameras[];
};

uniform uint rat_LightCount;
uniform uint rat_ActiveCameraCount;
uniform uvec2 rat_ScreenSize;

vec4 getSpotLightMinBoundingSphere(const in RatScratchPipelineSpotLight light)
{
	const float c = max(light.cutoff, RAT_SCRATCH_EPSILON);
	float h = light.attenuation;

	if (h <= 0.0)
		return vec4(light.position, 0.0);

	float radius = h / (2.0 * c * c);
	vec3 axis = safeNormalize(light.direction);

	return vec4(light.position + radius * axis, radius);
}

void getCameraPlanes(RatScratchPipelineCamera camera, out vec4[RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT] planes,
					 vec2 cellMin, vec2 cellMax)
{
	planes = vec4[](vec4(1.0, 0.0, 0.0, 1.0 - cellMin.x),	// left
					vec4(-1.0, 0.0, 0.0, -1.0 + cellMax.x), // right
					vec4(0.0, 1.0, 0.0, 1.0 - cellMin.y),	// bottom
					vec4(0.0, -1.0, 0.0, -1.0 + cellMax.y), // top
					vec4(0.0, 0.0, -1.0, 1.0),				// near,
					vec4(0.0, 0.0, 1.0, 1.0)				// far,
	);

	mat4 transposedProjectionViewTransform = transpose(camera.projectionViewTransform);

	for (uint i = 0; i < RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT; ++i)
	{
		vec4 plane = transposedProjectionViewTransform * planes[i];
		plane /= length(plane.xyz);

		planes[i] = plane;
	}
}

bool sphereIntersectsCell(RatScratchPipelineCamera camera, vec4 sphere, vec2 cellMin, vec2 cellMax)
{
	vec4[RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT] planes;
	getCameraPlanes(camera, planes, cellMin, cellMax);

	for (uint i = 0; i < RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT; ++i)
	{
		float distanceFromPlane = dot(sphere.xyz, planes[i].xyz) + planes[i].w;
		if (distanceFromPlane < -sphere.w)
		{
			return false;
		}
	}

	return true;
}

void tryAddLightToCell(uvec2 cellCoordinate, uint lightIndex, uint cameraIndex)
{
	uvec3 coordinate = uvec3(cellCoordinate, 0);
	uvec3 dimensions =
		uvec3(uvec2(ceil(vec2(rat_ScreenSize) / vec2(RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELL_SIZE_IN_PIXELS))),
			  RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL + 1);
	uint offset = dimensions.x * dimensions.y * dimensions.z * cameraIndex;
	uint index = coordinateToIndex(coordinate, dimensions);

	uint previousCount = atomicAdd(rat_LightCountIndices[index + offset], 1);
	if (previousCount < RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL)
	{
		uvec3 lightCellCoordinate = uvec3(cellCoordinate, previousCount + 1);
		uint lightCellIndex = coordinateToIndex(lightCellCoordinate, dimensions);
		rat_LightCountIndices[lightCellIndex + offset] = lightIndex;
	}
}

void testPointLight(RatScratchPipelineLight light, RatScratchPipelineCamera camera, vec2 cellMin, vec2 cellMax,
					uvec2 cellCoordinate, uint lightIndex, uint cameraIndex)
{
	RatScratchPipelinePointLight pointLight;
	ratGetLight(light, pointLight);

	vec4 sphere = vec4(pointLight.position, pointLight.attenuation);
	if (sphereIntersectsCell(camera, sphere, cellMin, cellMax))
	{
		tryAddLightToCell(cellCoordinate, lightIndex, cameraIndex);
	}
}

void testSpotLight(RatScratchPipelineLight light, RatScratchPipelineCamera camera, vec2 cellMin, vec2 cellMax,
				   uvec2 cellCoordinate, uint lightIndex, uint cameraIndex)
{
	RatScratchPipelineSpotLight spotLight;
	ratGetLight(light, spotLight);

	vec4 sphere = getSpotLightMinBoundingSphere(spotLight);
	if (sphereIntersectsCell(camera, sphere, cellMin, cellMax))
	{
		tryAddLightToCell(cellCoordinate, lightIndex, cameraIndex);
	}
}

void computemain()
{
	uint cellIndex = gl_GlobalInvocationID.x;
	uvec2 dimensions = uvec2(ceil(vec2(rat_ScreenSize) / vec2(RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELL_SIZE_IN_PIXELS)));
	uvec2 coordinate = indexToCoordinate(cellIndex, dimensions);
	if (coordinate.x >= dimensions.x || coordinate.y >= dimensions.y)
	{
		return;
	}

	uint activeCameraIndex = gl_GlobalInvocationID.z;
	if (activeCameraIndex >= rat_ActiveCameraCount)
	{
		return;
	}

	uint cameraIndex = rat_ActiveCameras[activeCameraIndex];
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];

	uint i = min(gl_GlobalInvocationID.y * RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_THREAD, rat_LightCount);
	uint j = min(i + RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_THREAD, rat_LightCount);

	vec2 cellMin = (vec2(2.0) * vec2(coordinate)) / vec2(dimensions);
	vec2 cellMax = (vec2(2.0) * vec2(coordinate + uvec2(1))) / vec2(dimensions);

	for (uint k = i; k < j; ++k)
	{
		RatScratchPipelineLight light = rat_Lights[k];
		switch (ratGetLightType(light))
		{
		case RAT_SCRATCH_LIGHT_TYPE_AMBIENT:
		case RAT_SCRATCH_LIGHT_TYPE_DIRECTIONAL:
			// These lights are always global.
			tryAddLightToCell(coordinate, k, cameraIndex);
			break;
		case RAT_SCRATCH_LIGHT_TYPE_POINT:
			testPointLight(light, camera, cellMin, cellMax, coordinate, k, cameraIndex);
			break;
		case RAT_SCRATCH_LIGHT_TYPE_SPOT:
			testSpotLight(light, camera, cellMin, cellMax, coordinate, k, cameraIndex);
			break;
		}
	}
}
