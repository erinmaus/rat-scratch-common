#include "@Pipeline/Common/Types/ReflectionProbe.common.glsl"

restrict readonly buffer rat_ReflectionProbesBuffer
{
	RatScratchPipelineReflectionProbe rat_ReflectionProbes[];
};

restrict readonly buffer rat_ReflectionProbeCountIndicesBuffer
{
	uint rat_ReflectionProbeCountIndices[];
};
