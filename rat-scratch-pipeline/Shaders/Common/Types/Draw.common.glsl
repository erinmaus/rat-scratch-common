struct RatScratchPipelineObjectInstance
{
	mat4 worldTransform;
	uvec2 modelInstanceIndexCount;
	uvec2 boneTransformIndexCount;
};

struct RatScratchPipelineModelInstance
{
	uint objectInstanceIndex;
	uint modelIndex;
};

struct RatScratchPipelineMeshInstance
{
	uint materialInstanceIndex;
};

struct RatScratchPipelineModel
{
	mat4 localTransform;
	uvec2 meshIndexCount;
};

struct RatScratchPipelineMesh
{
	uvec2 meshletCountIndex;
	uint staticBaseVertexOffset;
	uint skinnedBaseVertexOffset;
};

struct RatScratchPipelineMeshCluster
{
	vec4 boundsPositionRadius;
	float error;
	int refinedIndex;
	uvec2 indexOffsetCount;
};

struct RatScratchPipelineMeshClusterGroup
{
	vec4 boundsPositionRadius;
	float error;
	uint lodDepth;
	uvec2 clusterIndexCount;
};

struct RatScratchPipelineMeshClusterNode
{
	vec4 boundsPositionRadius;
	float error;
	uint groupIndex;
	uvec2 childIndexCount;
};

struct RatScratchPipelineMeshlet
{
	vec4 staticCenterRadius;
	uvec2 skinnedMeshletBoundsIndexCount;
};

struct RatScratchPipelineSkinnedMeshletBounds
{
	vec4 centerRadius;
	uint animationIndex;
	uint bone;
};

const uint RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT = 6;

const uint RAT_SCRATCH_PIPELINE_PROJECTION_TYPE_NONE = 0;
const uint RAT_SCRATCH_PIPELINE_PROJECTION_TYPE_PERSPECTIVE = 1;
const uint RAT_SCRATCH_PIPELINE_PROJECTION_TYPE_ORTHOGRAPHIC = 2;

struct RatScratchPipelineCamera
{
	mat4 viewTransform;
	mat4 inverseViewTransform;
	mat4 previousViewTransform;
	mat4 inversePreviousViewTransform;
	mat4 projectionTransform;
	mat4 inverseProjectionTransform;
	mat4 previousProjectionTransform;
	mat4 inversePreviousProjectionTransform;
	mat4 projectionViewTransform;
	mat4 inverseProjectionViewTransform;
	mat4 inversePreviousProjectionViewTransform;
	vec4 leftPlane;
	vec4 rightPlane;
	vec4 topPlane;
	vec4 bottomPlane;
	vec4 nearPlane;
	vec4 farPlane;
	uint projectionType;
};

struct RatScratchPipelineDraw
{
	uint objectInstanceIndex;
	uint modelInstanceIndex;
	uint meshInstanceIndex;
	uint modelIndex;
	uint meshIndex;
	uint meshletIndex;
	uint staticBaseVertexOffset;
	uint skinnedBaseVertexOffset;
	uvec2 boneOffsetCount;
	uint indexOffset;
	uint cameraIndex;
	uint layerIndex;
};
