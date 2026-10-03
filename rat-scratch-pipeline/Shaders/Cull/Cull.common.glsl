#include "@Generated/Pipeline/Config.common.glsl"
#include "@Pipeline/Common/Camera.common.glsl"

float ratCalculateScreenError(RatScratchPipelineCamera camera, vec3 boundsPosition, float boundsRadius, float error)
{
	float factor = ratGetCameraErrorFactor(camera);
	if (camera.projectionType == RAT_SCRATCH_PIPELINE_PROJECTION_TYPE_ORTHOGRAPHIC)
	{
		return error * factor;
	}

	vec3 cameraPosition = ratGetCameraPosition(camera);
	float zNear = ratGetCameraZNear(camera);

	float distanceFromCamera = length(boundsPosition - cameraPosition) - boundsRadius;
	return error * factor / max(distanceFromCamera, zNear);
}

void ratTransformBoundsSphere(mat4 worldTransform, inout vec3 position, inout float radius)
{
	position = (worldTransform * vec4(position, 1.0)).xyz;

	vec3 c0 = worldTransform[0].xyz;
	vec3 c1 = worldTransform[1].xyz;
	vec3 c2 = worldTransform[2].xyz;

	radius *= sqrt(dot(c0, c0) + dot(c1, c1) + dot(c2, c2));
}

bool ratSphereInsideFrustum(RatScratchPipelineCamera camera, vec3 position, float radius)
{
	vec4 planes[] = vec4[](camera.leftPlane, camera.rightPlane, camera.topPlane, camera.bottomPlane, camera.nearPlane,
						   camera.farPlane);

	for (uint i = 0; i < RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT; ++i)
	{
		float distanceFromPlane = dot(planes[i].xyz, position) + planes[i].w;
		if (distanceFromPlane < -radius)
		{
			return false;
		}
	}

	return true;
}

bool ratSelectGroupLOD(RatScratchPipelineCamera camera, RatScratchPipelineMeshClusterGroup clusterGroup,
					   mat4 worldTransform)
{
	float errorThreshold = RAT_SCRATCH_PIPELINE_CONFIG_LOD_ERROR_THRESHOLD;

	vec4 groupBoundsPositionRadius = clusterGroup.boundsPositionRadius;
	ratTransformBoundsSphere(worldTransform, groupBoundsPositionRadius.xyz, groupBoundsPositionRadius.w);

	if (!ratSphereInsideFrustum(camera, groupBoundsPositionRadius.xyz, groupBoundsPositionRadius.w))
	{
		return false;
	}

	if (ratCalculateScreenError(camera, groupBoundsPositionRadius.xyz, groupBoundsPositionRadius.w,
								clusterGroup.error) <= errorThreshold)
	{
		return false;
	}

	return true;
}

bool ratSelectClusterLOD(RatScratchPipelineCamera camera, RatScratchPipelineMeshCluster cluster, uint groupOffset,
						 mat4 worldTransform)
{
	float errorThreshold = RAT_SCRATCH_PIPELINE_CONFIG_LOD_ERROR_THRESHOLD;

	if (cluster.refinedIndex < 0)
	{
		return true;
	}

	RatScratchPipelineMeshClusterGroup refinedClusterGroup =
		rat_MeshClusterGroups[groupOffset + uint(cluster.refinedIndex)];

	vec4 groupBoundsPositionRadius = refinedClusterGroup.boundsPositionRadius;
	ratTransformBoundsSphere(worldTransform, groupBoundsPositionRadius.xyz, groupBoundsPositionRadius.w);

	if (ratCalculateScreenError(camera, groupBoundsPositionRadius.xyz, groupBoundsPositionRadius.w,
								refinedClusterGroup.error) <= errorThreshold)
	{
		return true;
	}

	return false;
}

void ratEmitClusterDraws(RatScratchPipelineDraw baseDraw, uint cameraIndex,
						 uint selectedClusters[RAT_SCRATCH_PIPELINE_CONFIG_LOD_MAX_PENDING_CLUSTER_DRAWS],
						 uint clusterCount)
{
	if (clusterCount == 0)
	{
		return;
	}

	uint drawStartIndex = atomicAdd(rat_IndirectDraws[cameraIndex].instanceCount, clusterCount);
	for (uint i = 0; i < clusterCount; ++i)
	{
		baseDraw.clusterIndex = selectedClusters[i];
		baseDraw.cameraIndex = cameraIndex;
		rat_OutputDraws[drawStartIndex + i] = baseDraw;
	}
}
