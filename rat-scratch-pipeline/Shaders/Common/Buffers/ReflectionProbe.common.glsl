#include "@Pipeline/Common/Types/ReflectionProbe.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"

uniform sampler2DArray rat_PipelineReflectionAtlasView;
uniform sampler2DArray rat_PipelineGlobalIlluminationAtlasView;
uniform sampler2DArray rat_PipelineReflectionMinMaxHiZAtlasView;

restrict readonly buffer rat_ReflectionProbesBuffer
{
	RatScratchPipelineReflectionProbe rat_ReflectionProbes[];
};

uniform uint rat_ReflectionProbeCount;

restrict readonly buffer rat_ReflectionProbeCountIndicesBuffer
{
	uint rat_ReflectionProbeCountIndices[];
};

restrict readonly buffer rat_ReflectionProbeCamerasBuffer
{
	RatScratchPipelineCamera rat_ReflectionProbeCameras[];
};
