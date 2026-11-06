#pragma language glsl4

#include "./Types.common.glsl"
#include "@Generated/Pipeline/Config.common.glsl"
#include "@Pipeline/PostProcess/Common.frag.glsl"
#include "@Pipeline/Common/Blend.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"

layout(r8ui) uniform uimage2DArray rat_OITABufferCount;

restrict readonly buffer rat_OITFragmentsBuffer
{
	RatScratchPipelineForwardOITFragment rat_OITFragments[];
};

layout(location = 0) out vec4 rat_Fragment;

void pixelmain()
{
	uvec4 dimensions = uvec4(RAT_SCRATCH_PIPELINE_CONFIG_FORWARD_OIT_SAMPLE_COUNT, imageSize(rat_OITABufferCount));
	ivec2 position = ivec2(frag_TextureCoordinate * vec2(imageSize(rat_OITABufferCount).xy));

	uint count = imageLoad(rat_OITABufferCount, ivec3(position, gl_Layer)).x;
	count = min(count, RAT_SCRATCH_PIPELINE_CONFIG_FORWARD_OIT_SAMPLE_COUNT - 1);

	vec4 result = vec4(0.0);
	for (uint i = 0; i < count; ++i)
	{
		uint j = count - i - 1;
		uvec4 coordinate = uvec4(j, position, gl_Layer);
		uint index = coordinateToIndex(coordinate, dimensions);
		vec4 color = unpackUnorm4x8(rat_OITFragments[index].color);
		result = alphaBlend(result, color);
	}

	rat_Fragment = result;
}
