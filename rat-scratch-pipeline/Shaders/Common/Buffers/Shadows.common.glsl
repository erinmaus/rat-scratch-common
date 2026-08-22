#include "@Pipeline/Common/Types/Shadows.common.glsl"

uniform sampler2DArray rat_PipelineShadowTextureAtlasView;

restrict readonly buffer rat_ShadowTexturesBuffer
{
	RatScratchPipelineShadowTexture rat_ShadowTextures[];
};