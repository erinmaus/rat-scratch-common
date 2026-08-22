struct RatScratchPipelineFragmentInput
{
	vec3 localPosition;
	vec3 worldPosition;
	vec4 position;
	vec3 screenPosition;
	// We currently sacrifice accuracy for non-uniform scale of the local transform
	// when calculating the local normal.
	vec3 localNormal;
	vec3 normal;
	vec3 tangent;
	vec3 bitangent;
	vec2 textureCoordinate;
	vec4 color;
	uint materialInstance;
	uint cameraIndex;
};

struct RatScratchPipelineFragmentOutput
{
	vec3 position;
	vec3 screenPosition;
	vec4 albedo;
	vec3 emissive;
	vec3 normal;
	float metal;
	float roughness;
	float occlusion;
	uint materialDefinitionIndex;
	uint cameraIndex;
};
