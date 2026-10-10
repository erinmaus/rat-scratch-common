#include "@Pipeline/Common/Types/Shadows.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"

uniform sampler2DArray rat_PipelineShadowTextureAtlasView;

restrict readonly buffer rat_ShadowTexturesBuffer
{
	RatScratchPipelineShadowTexture rat_ShadowTextures[];
};

restrict readonly buffer rat_ShadowCamerasBuffer
{
	RatScratchPipelineCamera rat_ShadowCameras[];
};
