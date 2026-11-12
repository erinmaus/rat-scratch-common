layout(local_size_x = 64) in;

#include "@Generated/Pipeline/Config.common.glsl"
#include "@Pipeline/Common/Types/Materials.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"
#include "@Pipeline/Common/Types/Indirect.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Materials.common.glsl"

restrict readonly buffer rat_InputDrawsBuffer
{
	RatScratchPipelineDraw rat_InputDraws[];
};

restrict readonly buffer rat_InputIndirectDrawsBuffer
{
	RatScratchPipelineIndirectDraw rat_InputIndirectDraws[];
};

restrict buffer rat_OutputIndirectDrawsBuffer
{
	RatScratchPipelineIndirectDraw rat_OutputIndirectDraws[];
};

restrict writeonly buffer rat_OutputOpaqueDrawsBuffer
{
	RatScratchPipelineDraw rat_OutputOpaqueDraws[];
};

restrict writeonly buffer rat_OutputBlendDrawsBuffer
{
	RatScratchPipelineDraw rat_OutputBlendDraws[];
};

restrict writeonly buffer rat_OutputMaskDrawsBuffer
{
	RatScratchPipelineDraw rat_OutputMaskDraws[];
};

void computemain()
{
	uint drawIndex = gl_GlobalInvocationID.x;
	uint maxDraws = rat_InputIndirectDraws[0].instanceCount;
	if (drawIndex >= maxDraws)
	{
		return;
	}

	RatScratchPipelineDraw draw = rat_InputDraws[drawIndex];
	RatScratchPipelineMeshInstance meshInstance = rat_MeshInstances[draw.meshInstanceIndex];
	RatScratchPipelineMaterialInstance materialInstance = rat_MaterialInstances[meshInstance.materialInstanceIndex];

	switch (materialInstance.alphaMode)
	{
	case RAT_SCRATCH_PIPELINE_ALPHA_MODE_OPAQUE:
	default: {
		uint index = atomicAdd(rat_OutputIndirectDraws[RAT_SCRATCH_PIPELINE_ALPHA_MODE_OPAQUE].instanceCount, 1);
		rat_OutputOpaqueDraws[index] = draw;
		break;
	}

	case RAT_SCRATCH_PIPELINE_ALPHA_MODE_BLEND: {
		uint index = atomicAdd(rat_OutputIndirectDraws[RAT_SCRATCH_PIPELINE_ALPHA_MODE_BLEND].instanceCount, 1);
		rat_OutputBlendDraws[index] = draw;
		break;
	}

	case RAT_SCRATCH_PIPELINE_ALPHA_MODE_MASK: {
		uint index = atomicAdd(rat_OutputIndirectDraws[RAT_SCRATCH_PIPELINE_ALPHA_MODE_MASK].instanceCount, 1);
		rat_OutputMaskDraws[index] = draw;
		break;
	}
	}
}
