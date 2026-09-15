#pragma language glsl4

#include "./Types.common.glsl"

uniform sampler2D MainTex;

restrict buffer rat_TransparentPixelCounterBuffer
{
	uint rat_TransparentPixelCounter[];
};

layout(r32i) restrict uniform iimage2D rat_ABufferImage;

restrict writeonly buffer rat_ABufferFragmentsBuffer
{
	RatScratchABufferFragment rat_ABufferFragments[];
};

uniform uint rat_ABufferFragmentsCount;
uniform uint rat_BlendMode;

void storeFragment(vec4 color)
{
	ivec2 fragCoord = ivec2(gl_FragCoord.xy);
	uint fragmentIndex = atomicAdd(rat_TransparentPixelCounter[0], 1);
	if (fragmentIndex >= rat_ABufferFragmentsCount)
	{
		return;
	}

	rat_ABufferFragments[fragmentIndex].color = color;
	rat_ABufferFragments[fragmentIndex].depth = gl_FragCoord.z;
	rat_ABufferFragments[fragmentIndex].blendMode = rat_BlendMode;
	rat_ABufferFragments[fragmentIndex].next = -1;

	int currentHead = imageAtomicExchange(rat_ABufferImage, fragCoord, int(fragmentIndex));
	rat_ABufferFragments[fragmentIndex].next = currentHead;
}

void effect()
{
	vec4 textureSample = texture(MainTex, VaryingTexCoord.st);
	vec4 resultColor = textureSample * VaryingColor;

	if (resultColor.a > 0.0 && resultColor.a < 1.0)
	{
		storeFragment(resultColor);
		resultColor.a = 0.0;
	}

	love_PixelColor = resultColor;
}
