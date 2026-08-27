const uint RAT_SCRATCH_MATERIAL_TYPE_$RAT_SCRATCH_MATERIAL$ = $RAT_SCRATCH_MATERIAL_DEFINITION_INDEX$;

struct RatScratch$RAT_SCRATCH_MATERIAL$MaterialProperties
{
	/*** $("@Pipeline/Base/Material/GetMaterialsPropertiesStructField.template.glsl", $RAT_SCRATCH_PROPERTIES$) ***/
};

void ratGet$RAT_SCRATCH_MATERIAL$MaterialProperties(
	uint materialInstance, out RatScratch$RAT_SCRATCH_MATERIAL$MaterialProperties materialProperties)
{
	uint baseIntIndex = materialInstance * $RAT_SCRATCH_MATERIAL_PROPERTIES_STRIDE$ + $RAT_SCRATCH_BASE_OFFSET$;
	uint baseFloatIndex = materialInstance * $RAT_SCRATCH_MATERIAL_PROPERTIES_STRIDE$ + $RAT_SCRATCH_BASE_OFFSET$;

	/*** $("@Pipeline/Base/Material/GetMaterialsIntProperty.template.glsl", $RAT_SCRATCH_INT_PROPERTIES$) ***/
	/*** $("@Pipeline/Base/Material/GetMaterialsFloatProperty.template.glsl", $RAT_SCRATCH_FLOAT_PROPERTIES$) ***/
}
