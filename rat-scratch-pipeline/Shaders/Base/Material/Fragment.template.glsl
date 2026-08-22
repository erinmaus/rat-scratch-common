#include "@Pipeline/Common/Types/Fragment.common.glsl"

void ratApplyNoneFragmentMaterial(in RatScratchPipelineFragmentInput fragmentInput,
								  out RatScratchPipelineFragmentOutput fragmentOutput)
{
	// Nothing.
}

/*** $("@Pipeline/Base/Material/FragmentApplyMaterialImpl.template.glsl", $RAT_SCRATCH_MATERIALS$) ***/

void ratFragmentApplyMaterial(in RatScratchPipelineFragmentInput fragmentInput,
							  out RatScratchPipelineFragmentOutput fragmentOutput)
{
	uint materialDefinitionIndex = rat_MaterialInstances[fragmentInput.materialInstance].materialDefinitionIndex;
	fragmentOutput.materialDefinitionIndex = materialDefinitionIndex;

	switch (materialDefinitionIndex)
	{
		/*** $("@Pipeline/Base/Material/FragmentApplyMaterialCase.template.glsl", $RAT_SCRATCH_MATERIALS$) ***/
	}
}
