#include "@Pipeline/Common/Types/Textures.common.glsl"

uniform sampler2DArray rat_PipelineGammaCorrectTextureAtlasView;
uniform sampler2DArray rat_PipelineLinearTextureAtlasView;

restrict readonly buffer rat_TexturesBuffer
{
	RatScratchPipelineTexture rat_Textures[];
};
