#include "@Pipeline/Common/Types/Draw.common.glsl"

void getCellPlaneMinMax(uvec2 coordinate, uvec2 dimensions, out vec2 cellMin, out vec2 cellMax)
{
	cellMin = (vec2(2.0) * vec2(coordinate)) / vec2(dimensions);
	cellMax = (vec2(2.0) * vec2(coordinate + uvec2(1))) / vec2(dimensions);
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

bool sphereInsideFrustum(vec4[RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT] planes, vec4 sphere)
{

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

bool boundsInsideFrustum(vec4[RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT] planes, vec3 boundsMin, vec3 boundsMax)
{
	for (int i = 0; i < RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT; ++i)
	{
		int outside = 0;
		outside += dot(planes[i], vec4(boundsMin.x, boundsMin.y, boundsMin.z, 1.0f)) < 0.0 ? 1 : 0;
		outside += dot(planes[i], vec4(boundsMax.x, boundsMin.y, boundsMin.z, 1.0f)) < 0.0 ? 1 : 0;
		outside += dot(planes[i], vec4(boundsMin.x, boundsMax.y, boundsMin.z, 1.0f)) < 0.0 ? 1 : 0;
		outside += dot(planes[i], vec4(boundsMax.x, boundsMax.y, boundsMin.z, 1.0f)) < 0.0 ? 1 : 0;
		outside += dot(planes[i], vec4(boundsMin.x, boundsMin.y, boundsMax.z, 1.0f)) < 0.0 ? 1 : 0;
		outside += dot(planes[i], vec4(boundsMax.x, boundsMin.y, boundsMax.z, 1.0f)) < 0.0 ? 1 : 0;
		outside += dot(planes[i], vec4(boundsMin.x, boundsMax.y, boundsMax.z, 1.0f)) < 0.0 ? 1 : 0;
		outside += dot(planes[i], vec4(boundsMax.x, boundsMax.y, boundsMax.z, 1.0f)) < 0.0 ? 1 : 0;

		if (outside == 8)
		{
			return false;
		}
	}

	return true;
}
