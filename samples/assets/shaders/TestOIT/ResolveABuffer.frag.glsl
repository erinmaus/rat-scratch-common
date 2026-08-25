#pragma language glsl4

#include "./Types.common.glsl"

layout(r32i) restrict uniform iimage2D rat_ABufferImage;

restrict readonly buffer rat_ABufferFragmentsBuffer
{
	RatScratchABufferFragment rat_ABufferFragments[];
};

uniform sampler2D MainTex;

struct Fragment
{
	vec4 color;
	float depth;
	uint blendMode;
};

uniform uvec2 rat_ABufferSize;

void pullFragments(vec2 textureCoordinate, out Fragment fragments[RAT_SCRATCH_MAX_FRAGMENTS], out uint count)
{
	count = 0;

	ivec2 fragCoord = ivec2(textureCoordinate * vec2(imageSize(rat_ABufferImage)));
	int current = imageLoad(rat_ABufferImage, fragCoord).r;

	while (current >= 0 && count < RAT_SCRATCH_MAX_FRAGMENTS)
	{
		RatScratchABufferFragment inputFragment = rat_ABufferFragments[current];

		fragments[count].color = inputFragment.color;
		fragments[count].depth = inputFragment.depth;
		fragments[count].blendMode = inputFragment.blendMode;

		current = inputFragment.next;
		++count;
	}
}

void sortFragments(uint count, in Fragment fragments[RAT_SCRATCH_MAX_FRAGMENTS],
				   out uint sortedFragmentIndices[RAT_SCRATCH_MAX_FRAGMENTS])
{
	for (uint i = 0; i < count; ++i)
	{
		sortedFragmentIndices[i] = i;
	}

	for (int i = 1; i < count; ++i)
	{
		for (int j = i;
			 j > 0 && fragments[sortedFragmentIndices[j]].depth > fragments[sortedFragmentIndices[j - 1]].depth; --j)
		{
			uint a = sortedFragmentIndices[j];
			uint b = sortedFragmentIndices[j - 1];

			sortedFragmentIndices[j] = b;
			sortedFragmentIndices[j - 1] = a;
		}
	}
}

vec4 alphaBlend(vec4 destination, vec4 source)
{
	vec4 result = destination;

	result.rgb *= vec3(1.0 - source.a);
	result.rgb += vec3(source.a) * source.rgb;
	result.a *= 1.0 - source.a;
	result.a += source.a;
	result.a = clamp(result.a, 0.0, 1.0);

	return result;
}

void effect()
{
	vec4 resultSample = texture(MainTex, VaryingTexCoord.xy);

	Fragment fragments[RAT_SCRATCH_MAX_FRAGMENTS];
	uint count = 0;
	pullFragments(VaryingTexCoord.xy, fragments, count);

	uint sortedFragmentIndices[RAT_SCRATCH_MAX_FRAGMENTS];
	sortFragments(count, fragments, sortedFragmentIndices);

	for (uint i = 0; i < count; ++i)
	{
		Fragment fragment = fragments[sortedFragmentIndices[i]];

		if (fragment.blendMode == RAT_SCRATCH_FRAGMENT_BLEND_MODE_ALPHA)
		{
			resultSample = alphaBlend(resultSample, fragment.color);
		}
		else if (fragment.blendMode == RAT_SCRATCH_FRAGMENT_BLEND_MODE_ADD)
		{
			resultSample.rgb += fragment.color.rgb * vec3(fragment.color.a);
			resultSample.a += fragment.color.a;
		}
		else if (fragment.blendMode == RAT_SCRATCH_FRAGMENT_BLEND_MODE_MULTIPLY)
		{
			resultSample *= fragment.color;
		}
	}

	love_PixelColor = resultSample;
}
