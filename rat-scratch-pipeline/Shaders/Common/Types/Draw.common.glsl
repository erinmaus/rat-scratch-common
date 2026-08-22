struct RatScratchPipelineObjectInstance
{
	mat4 worldTransform;
	uvec2 modelInstanceIndexCount;
	uvec2 animationPlaybackIndexCount;
};

struct RatScratchPipelineAnimationPlayback
{
	uint animationIndex;
};

struct RatScratchPipelineModelInstance
{
	uint objectInstanceIndex;
	uint modelIndex;
	uvec2 boneTransformIndexCount;
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

struct RatScratchPipelineCamera
{
	mat4 viewTransform;
	mat4 inverseViewTransform;
	mat4 projectionTransform;
	mat4 inverseProjectionTransform;
	mat4 viewProjectionTransform;
	mat4 inverseViewProjectionTransform;
};
