#include "@Pipeline/Common/Textures/Uniforms.common.glsl"
#include "@Pipeline/Common/Types/Textures.common.glsl"

vec4 ratDirectSampleTexture(sampler2DArray atlasTexture, uint textureIndex, vec2 textureCoordinate)
{
	RatScratchPipelineTexture textureAtlasInfo = rat_PipelineTextures[textureIndex];
	vec2 wrappedTextureCoordinate = textureCoordinate - floor(textureCoordinate);
	vec2 atlasTextureCoordinate = wrappedTextureCoordinate * textureAtlasInfo.size + textureAtlasInfo.position;

	return texture(atlasTexture, vec3(atlasTextureCoordinate, textureAtlasInfo.layer));
}

vec4 ratSampleTexture(uint textureIndex, vec2 textureCoordinate)
{
	ratDirectSampleTexture(rat_PipelineGammaCorrectTextureAtlasView, textureIndex, textureCoordinate);
}

vec4 ratSampleLinearTexture(uint textureIndex, vec2 textureCoordinate)
{
	ratDirectSampleTexture(rat_PipelineLinearTextureAtlasView, textureIndex, textureCoordinate);
}

vec3 ratSampleNormalTexture(uint textureIndex, vec2 textureCoordinate)
{
	vec4 textureSample = ratSampleLinearTexture(textureIndex, textureCoordinate);
	return textureSample.xyz * vec3(2.0) - vec3(1.0);
}

float ratSampleOcclusionTexture(uint textureIndex, vec2 textureCoordinate)
{
	return ratSampleLinearTexture(rat_PipelineLinearTextureAtlasView)
}