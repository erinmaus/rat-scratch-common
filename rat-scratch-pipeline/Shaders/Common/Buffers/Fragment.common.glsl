#include "@Pipeline/Common/Types/Fragment.common.glsl"

varying vec3 frag_LocalPosition;
varying vec3 frag_WorldPosition;
varying vec3 frag_ScreenPosition;
varying vec4 frag_Position;
varying vec3 frag_LocalNormal;
varying vec3 frag_Normal;
varying vec3 frag_Tangent;
varying vec3 frag_Bitanget;
varying vec2 frag_TextureCoordinate;
varying vec4 frag_Color;
varying uint frag_MaterialInstance;
varying uint frag_CameraIndex;

void ratClearFragmentInput(out RatScratchPipelineFragmentInput fragmentInput)
{
	fragmentInput.localPosition = vec3(0.0);
	fragmentInput.worldPosition = vec3(0.0);
	fragmentInput.position = vec3(0.0);
	fragmentInput.screenPosition = vec4(0.0);
	fragmentInput.localNormal = vec3(0.0);
	fragmentInput.normal = vec3(0.0);
	fragmentInput.tangent = vec3(0.0);
	fragmentInput.bitangent = vec3(0.0);
	fragmentInput.textureCoordinate = vec2(0.0);
	fragmentInput.color = vec4(0.0);
	fragmentInput.materialInstance = 0;
	fragmentInput.cameraIndex = 0;
}

void ratGetFragmentInput(out RatScratchPipelineFragmentInput fragmentInput)
{
	fragmentInput.localPosition = frag_LocalPosition;
	fragmentInput.worldPosition = frag_WorldPosition;
	fragmentInput.position = frag_ScreenPosition;
	fragmentInput.screenPosition = frag_Position;
	fragmentInput.localNormal = frag_LocalNormal;
	fragmentInput.normal = frag_Normal;
	fragmentInput.tangent = frag_Tangent;
	fragmentInput.bitangent = frag_Bitanget;
	fragmentInput.textureCoordinate = frag_TextureCoordinate;
	fragmentInput.color = frag_Color;
	fragmentInput.materialInstance = frag_MaterialInstance;
	fragmentInput.cameraIndex = frag_CameraIndex;
}

void ratSetVertexOutputs(in RatScratchPipelineFragmentInput fragmentInput)
{
	frag_LocalPosition = fragmentInput.localPosition;
	frag_WorldPosition = fragmentInput.worldPosition;
	frag_ScreenPosition = fragmentInput.position;
	frag_Position = fragmentInput.screenPosition;
	frag_LocalNormal = fragmentInput.localNormal;
	frag_Normal = fragmentInput.normal;
	frag_Tangent = fragmentInput.tangent;
	frag_Bitanget = fragmentInput.bitangent;
	frag_TextureCoordinate = fragmentInput.textureCoordinate;
	frag_Color = fragmentInput.color;
	frag_MaterialInstance = fragmentInput.materialInstance;
	frag_CameraIndex = fragmentInput.cameraIndex;
}

void ratClearFragmentOutput(out RatScratchPipelineFragmentOutput fragmentOutput)
{
	fragmentOutput.position = vec3(0.0);
	fragmentOutput.screenPosition = vec3(0.0);
	fragmentOutput.albedo = vec4(0.0);
	fragmentOutput.emissive = vec3(0.0);
	fragmentOutput.normal = vec3(0.0);
	fragmentOutput.metal = 1;
	fragmentOutput.roughness = 1;
	fragmentOutput.occlusion = 1;
	fragmentOutput.materialDefinitionIndex = 0;
}
