const uint RAT_SCRATCH_MATERIAL_TYPE_$RAT_SCRATCH_MATERIAL$ = $RAT_SCRATCH_MATERIAL_DEFINITION_INDEX$;

void ratGet$RAT_SCRATCH_MATERIAL$MaterialProperties(
	uint materialInstance, out RatScratch$RAT_SCRATCH_MATERIAL$MaterialProperties materialProperties)
{
	uint baseIntIndex = materialInstance * RAT_SCRATCH_MATERIAL_PROPERTIES_INT_STRIDE;
	uint baseFloatIndex = materialInstance * RAT_SCRATCH_MATERIAL_PROPERTIES_FLOAT_STRIDE;

	/*** $("@Pipeline/Base/Material/GetMaterialsIntProperty.template.glsl", $RAT_SCRATCH_INT_PROPERTIES$) ***/
	/*** $("@Pipeline/Base/Material/GetMaterialsFloatProperty.template.glsl", $RAT_SCRATCH_FLOAT_PROPERTIES$) ***/
}
