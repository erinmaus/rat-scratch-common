#pragma language glsl4

#include "@Pipeline/Common/Gaussian.common.glsl"
#include "@Pipeline/PostProcess/Common.frag.glsl"

uniform sampler2DArray rat_ShadowTexture;
uniform ivec2 rat_BlurDirection;

layout(location = 0) out vec2 rat_ShadowBufferDepth;

void pixelmain()
{
	ivec2 texelPosition = ivec2(frag_TextureCoordinate * vec2(textureSize(rat_ShadowTexture, 0).xy));
	vec4 blurredSample = ratGaussian21(rat_ShadowTexture, rat_BlurDirection, ivec3(texelPosition, gl_Layer), 0);

	rat_ShadowBufferDepth = blurredSample.xy;
}
