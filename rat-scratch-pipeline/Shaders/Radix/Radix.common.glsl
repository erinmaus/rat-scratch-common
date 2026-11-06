#extension GL_KHR_shader_subgroup_basic : enable
#extension GL_KHR_shader_subgroup_arithmetic : enable

#include "./Common.common.glsl"

shared uint[RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT] rat_RadixSharedHistogram;
shared uint[RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT / RAT_SCRATCH_PIPELINE_MIN_SUBGROUP_SIZE] rat_RadixSharedSum;
shared uint[RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT] rat_RadixSharedLocalOffsets;
shared uint[RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT] rat_RadixSharedGlobalOffsets;

struct RatScratchPipelineRadixBinFlags
{
	uint flags[gl_WorkGroupSize.x / 32];
};

shared RatScratchPipelineRadixBinFlags[RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT] rat_RadixSharedBinFlags;

uint ratRadixGetElementCount();
uint ratRadixGetResultKey(uint index);
uint ratRadixGetScratchKey(uint index);
void ratRadixSwapFromResultToScratch(uint sourceIndex, uint destinationIndex);
void ratRadixSwapFromScratchToResult(uint sourceIndex, uint destinationIndex);

uint ratRadixGetKey(uint index, uint iteration)
{
	if ((iteration & 0x1) == 0)
	{
		return ratRadixGetResultKey(index);
	}

	return ratRadixGetScratchKey(index);
}

void ratRadixSort()
{
	for (uint i = 0; i < RAT_SCRATCH_PIPELINE_ITERATIONS; i++)
	{
		uint currentBitCount = findMSB(RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT);
		uint currentShift = currentBitCount * i;

		if (gl_LocalInvocationID.x < RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT)
		{
			rat_RadixSharedHistogram[gl_LocalInvocationID.x] = 0;
		}

		barrier();

		for (uint j = gl_LocalInvocationID.x; j < ratRadixGetElementCount(); j += gl_WorkGroupSize.x)
		{
			uint bin =
				uint(ratRadixGetKey(j, i) >> currentShift) & uint(RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT - 1);
			atomicAdd(rat_RadixSharedHistogram[bin], 1);
		}

		barrier();

		uint rat_RadixSharedHistogramCount = 0;
		if (gl_LocalInvocationID.x < RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT)
		{
			rat_RadixSharedHistogramCount = rat_RadixSharedHistogram[gl_LocalInvocationID.x];
		}

		uint sum = subgroupAdd(rat_RadixSharedHistogramCount);
		uint prefixSum = subgroupExclusiveAdd(rat_RadixSharedHistogramCount);
		if (gl_LocalInvocationID.x < RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT)
		{
			rat_RadixSharedLocalOffsets[gl_LocalInvocationID.x] = prefixSum;
		}

		if (subgroupElect())
		{
			if (gl_SubgroupID < (RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT / gl_SubgroupSize))
			{
				rat_RadixSharedSum[gl_SubgroupID] = sum;
			}
		}

		barrier();

		if (gl_SubgroupID == 0)
		{
			uint offset = 0;
			for (uint i = gl_SubgroupInvocationID; i < RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT; i += gl_SubgroupSize)
			{
				rat_RadixSharedGlobalOffsets[i] = offset + rat_RadixSharedLocalOffsets[i];
				offset += rat_RadixSharedSum[i / gl_SubgroupSize];
			}
		}

		barrier();

		uint flagsBinIndex = gl_LocalInvocationID.x / 32;
		uint flagsBit = 1 << (gl_LocalInvocationID.x % 32);

		for (uint blockOffset = 0; blockOffset < ratRadixGetElementCount(); blockOffset += gl_WorkGroupSize.x)
		{
			barrier();

			uint elementIndex = blockOffset + gl_LocalInvocationID.x;

			if (gl_LocalInvocationID.x < RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT)
			{
				for (int i = 0; i < gl_WorkGroupSize.x / 32; i++)
				{
					rat_RadixSharedBinFlags[gl_LocalInvocationID.x].flags[i] = 0; // init all bin flags to 0
				}
			}
			barrier();

			uint key = 0;
			uint binIndex = 0;
			uint binOffset = 0;
			if (elementIndex < ratRadixGetElementCount())
			{
				key = ratRadixGetKey(elementIndex, i);
				binIndex = uint((key >> currentShift)) & uint(RAT_SCRATCH_PIPELINE_RADIX_SORT_BINS_COUNT - 1);
				binOffset = rat_RadixSharedGlobalOffsets[binIndex];
				atomicAdd(rat_RadixSharedBinFlags[binIndex].flags[flagsBinIndex], flagsBit);
			}

			barrier();

			if (elementIndex < ratRadixGetElementCount())
			{
				uint prefix = 0;
				uint count = 0;
				for (uint j = 0; j < gl_WorkGroupSize.x / 32; j++)
				{
					uint bits = rat_RadixSharedBinFlags[binIndex].flags[j];
					uint fullBitCount = bitCount(bits);
					uint partialBitCount = bitCount(bits & (flagsBit - 1));

					prefix += (j < flagsBinIndex) ? fullBitCount : 0;
					prefix += (j == flagsBinIndex) ? partialBitCount : 0;
					count += fullBitCount;
				}

				if ((i & 1) == 0)
				{
					ratRadixSwapFromResultToScratch(elementIndex, binOffset + prefix);
				}
				else
				{
					ratRadixSwapFromScratchToResult(elementIndex, binOffset + prefix);
				}

				if (prefix == count - 1)
				{
					atomicAdd(rat_RadixSharedGlobalOffsets[binIndex], count);
				}
			}
		}
	}
}