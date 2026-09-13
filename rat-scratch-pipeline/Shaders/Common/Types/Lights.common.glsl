struct RatScratchPipelineLight
{
	// a for uv, 0 = visible, > 0 = ultra-violet
	vec4 color;
	// encoded normal
	vec2 direction;
	// w > 0 for direction, w == 0.0 for point / spot, < -1 for ambient light
	vec4 position;
	// x = attenuation or ambience, y = cutoff (< 0 for point light, >= 0 for spot light)
	vec2 attenuation;

	// x = index, y = count (0 for no shadows)
	// y = 6 for point lights, 0 or 1 for other lights for now (no cascading)
	uvec2 shadowTextureIndexCount;
};

struct RatScratchPipelineAmbientLight
{
	vec4 color;
	float ultraviolet;
	float ambience;
	uvec2 occlusionTextureIndexCount;
};

struct RatScratchPipelineDirectionalLight
{
	vec4 color;
	float ultraviolet;
	vec3 direction;
	uvec2 shadowTextureIndexCount;
};

struct RatScratchPipelinePointLight
{
	vec4 color;
	float ultraviolet;
	vec3 position;
	float attenuation;
	uvec2 shadowTextureIndexCount;
};

struct RatScratchPipelineSpotLight
{
	vec4 color;
	float ultraviolet;
	vec3 position;
	vec3 direction;
	float attenuation;
	float cutoff;
	uvec2 shadowTextureIndexCount;
};

struct RatScratchPipelineLightResult
{
	vec4 diffuse;
	vec4 specular;
	vec4 fluorescence;
};
