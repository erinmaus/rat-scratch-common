void ratGet$RAT_SCRATCH_ROLE$(in RatScratchPipelineVertex vertex, uint index)
{
	index *= $RAT_SCRATCH_COMPONENTS_COUNT$;
	index += $RAT_SCRATCH_ATTRIBUTE_OFFSET$;
	$RAT_SCRATCH_ATTRIBUTE_TYPE$ value = $RAT_SCRATCH_ATTRIBUTE_TYPE$(
		/*** $("@Pipeline/Base/Vertex/GetVertexAttributeValue.template.glsl", $RAT_SCRATCH_ATTRIBUTE_VALUES$) ***/
	);
	vertex.$RAT_SCRATCH_ATTRIBUTE_NAME$ = $RAT_SCRATCH_TRANSFORM_FUNC$(value);
}