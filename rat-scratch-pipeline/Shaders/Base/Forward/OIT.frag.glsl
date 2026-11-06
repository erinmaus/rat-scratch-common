#include "./Types.common.glsl"
#include "@Generated/Pipeline/Config.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"
#include "@Pipeline/Common/Blend.common.glsl"

layout(r8ui) restrict coherent uniform uimage2DArray rat_OITABufferCount;
layout(r32ui) restrict coherent uniform uimage2DArray rat_OITABufferLock;

restrict coherent buffer rat_OITFragmentsBuffer
{
	RatScratchPipelineForwardOITFragment rat_OITFragments[];
};

void ratForwardOITWrite(ivec3 coordinate, vec4 color, float depth)
{
	if (color.a == 0.0)
	{
		return;
	}

	// gl_SampleMaskIn[0] is only 0 in helper threads.
	// The spin-lock will freeze if we don't check due to how helper threads work.
	uint mask = gl_SampleMaskIn[0];
	bool done = mask == 0;

	while (!done)
	{
		uint lockValue = imageAtomicExchange(rat_OITABufferLock, coordinate, 1);
		if (lockValue == 0)
		{
			// Enter critical section.
			uvec4 dimensions =
				uvec4(RAT_SCRATCH_PIPELINE_CONFIG_FORWARD_OIT_SAMPLE_COUNT, imageSize(rat_OITABufferCount));
			uint currentSampleCount = imageLoad(rat_OITABufferCount, coordinate).x;

			uint target = currentSampleCount;
			for (uint i = 0; i < currentSampleCount; ++i)
			{
				uint index = coordinateToIndex(uvec4(i, coordinate), dimensions);

				RatScratchPipelineForwardOITFragment currentFragment = rat_OITFragments[index];
				if (depth <= currentFragment.depth)
				{
					target = i;
					break;
				}
			}

			for (int i = int(min(currentSampleCount - 1, RAT_SCRATCH_PIPELINE_CONFIG_FORWARD_OIT_SAMPLE_COUNT - 1));
				 i >= int(target); --i)
			{
				uint j = min(i + 1, RAT_SCRATCH_PIPELINE_CONFIG_FORWARD_OIT_SAMPLE_COUNT - 1);
				uint iIndex = coordinateToIndex(uvec4(i, coordinate), dimensions);
				uint jIndex = coordinateToIndex(uvec4(j, coordinate), dimensions);

				RatScratchPipelineForwardOITFragment fragment = rat_OITFragments[iIndex];
				rat_OITFragments[jIndex].depth = fragment.depth;
				rat_OITFragments[jIndex].color = fragment.color;
			}

			if (target < RAT_SCRATCH_PIPELINE_CONFIG_FORWARD_OIT_SAMPLE_COUNT)
			{
				uint index = coordinateToIndex(uvec4(target, coordinate), dimensions);

				rat_OITFragments[index].depth = depth;
				rat_OITFragments[index].color = packUnorm4x8(color);
			}

			imageStore(
				rat_OITABufferCount, coordinate,
				uvec4(min(currentSampleCount + 1, RAT_SCRATCH_PIPELINE_CONFIG_FORWARD_OIT_SAMPLE_COUNT), 0, 0, 0));

			imageAtomicExchange(rat_OITABufferLock, coordinate, 0);
			done = true;
		}
	}
}
