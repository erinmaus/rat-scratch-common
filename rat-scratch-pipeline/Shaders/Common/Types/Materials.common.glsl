const uint RAT_SCRATCH_PIPELINE_ALPHA_MODE_OPAQUE = 0;
const uint RAT_SCRATCH_PIPELINE_ALPHA_MODE_BLEND = 1;
const uint RAT_SCRATCH_PIPELINE_ALPHA_MODE_MASK = 2;

struct RatScratchPipelineMaterialInstance
{
	uint materialDefinitionIndex;
	uint alphaMode;
};
