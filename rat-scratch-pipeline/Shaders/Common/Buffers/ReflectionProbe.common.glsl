#include "@Pipeline/Common/Types/ReflectionProbe.common.glsl"

restrict readonly buffer rat_ReflectionProbesBuffer
{
	RatScratchPipelineReflectionProbe rat_ReflectionProbes[];
};

restrict readonly buffer rat_ReflectionProbeIndicesBuffer
{
	uint rat_ReflectionProbeIndices[];
};
