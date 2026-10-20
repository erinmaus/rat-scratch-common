#include "@Pipeline/Common/Types/ReflectionProbe.common.glsl"

uniform sampler2DArray rat_PipelineReflectionAtlasView;
uniform sampler2DArray rat_PipelineGlobalIlluminationAtlasView;

restrict readonly buffer rat_ReflectionProbesBuffer
{
	RatScratchPipelineReflectionProbe rat_ReflectionProbes[];
};

restrict readonly buffer rat_ReflectionProbeCountIndicesBuffer
{
	uint rat_ReflectionProbeCountIndices[];
};
