#include "@Pipeline/Common/Types/Lights.common.glsl"

restrict readonly buffer rat_LightsBuffer
{
	RatScratchPipelineLight rat_Lights[];
};

restrict readonly buffer rat_LightCountIndicesBuffer
{
	uint rat_LightCountIndices[];
};
