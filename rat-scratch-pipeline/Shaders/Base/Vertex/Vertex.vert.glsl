#pragma language glsl4

#include "generated://Pipeline/Material/Properties.common.glsl"
#include "generated://Pipeline/Material/Vertex.vert.glsl"
#include "generated://Pipeline/Vertex.vert.glsl"

#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Fragment.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"

restrict readonly buffer rat_DrawsBuffer
{
	RatScratchPipelineDraw rat_Draws[];
};

void ratVertexSkinnedDraw(in RatScratchPipelineDraw draw, out RatScratchPipelineFragmentInput fragment,
						  uint indexOffset)
{
	RatScratchPipelineCamera camera = rat_Camera[draw.cameraIndex];
	uint staticIndex = rat_Indices[draw.indexOffsetCount.x + indexOffset] + draw.staticBaseVertexOffset;
	uint skinnedIndex = rat_Indices[draw.indexOffsetCount.x + indexOffset] + draw.skinnedBaseVertexOffset;

	RatScratchPipelineVertex vertex;
	ratGetStaticVertex(vertex, staticIndex);
	ratGetSkinnedVertex(vertex, staticIndex);

	vec4 transformedPosition = vec4(0.0);
	vec3 transformedNormal = vec3(0.0);
	vec3 transformedTangent = vec3(0.0);

	mat4 boneTransform = mat4(0.0);
	for (uint i = 0; i < RAT_SCRATCH_MAX_BONES_PER_VERTEX; ++i)
	{
		uint boneIndex = draw.boneOffset + vertex.boneIndex[i];
		float weight = vertex.boneWeight[i];

		if (weight > 0.0)
		{
			boneTransform += rat_ObjectInstanceBoneTransforms[boneID] * weight;
		}
	}

	mat4 worldTransform = rat_PipelineObjectInstances[draw.objectInstanceIndex].worldTransform;
	mat4 localTransform = rat_PipelineModels[draw.modelIndex].localTransform;
	vec3 boneWorldLocalTransform = worldTransform * localTransform * boneTransform;

	mat4 normalTransform = transpose(inverse(mat3(boneWorldLocalTransform)));
	vec4 transformedPosition = boneWorldLocalTransform * vec4(vertex.position, 1.0);
	vec3 transformedNormal = normalize(normalTransform * vertex.normal);
	vec3 transformedTangent = normalize(normalTransform * vertex.tangent.xyz);

	vec4 localPosition = localTransform * vec4(vertex.position, 1.0);

	RatScratchPipelineCamera camera = rat_Camera[draw.cameraIndex];

	fragment.localPosition = localPosition.xyz;
	fragment.worldPosition = worldTransform;
	fragment.position = camera.projectionTransform * camera.viewTransform * worldPosition;
	fragment.screenPosition = fragment.position.xyz / fragment.position.w;
	fragment.screenPosition += vec3(1.0);
	fragment.screenPosition *= vec3(0.5);
	fragment.localNormal = normalize(mat3(localTransform) * localPosition);
	fragment.normal = transformedNormal;
	fragment.tangent = transformedTangent;
	fragment.bitangent = normalize(vec3(vertex.tangent.w) * cross(fragment.normal, fragment.tangent));
	fragment.textureCoordinate = vertex.textureCoordinate;
	fragment.color = vertex.color;
	fragment.material = rat_MeshInstance[draw.meshInstance].materialInstanceIndex;
}

void ratVertexStaticDraw(in RatScratchPipelineDraw draw, out RatScratchPipelineFragmentInput fragment, uint indexOffset)
{
	RatScratchPipelineCamera camera = rat_Camera[draw.cameraIndex];
	uint staticIndex = rat_Indices[draw.indexOffsetCount + indexOffset] + draw.staticBaseVertexOffset;

	RatScratchPipelineVertex vertex;
	ratGetStaticVertex(vertex, staticIndex);

	mat4 worldTransform = rat_PipelineObjectInstances[draw.objectInstanceIndex].worldTransform;
	mat4 localTransform = rat_PipelineModels[draw.modelIndex].localTransform;
	mat4 worldLocalTransform = worldTransform * localTransform;
	mat4 normalTransform = transpose(inverse(mat3(worldLocalTransform)));

	vec4 localPosition = localTransform * vec4(vertex.position, 1.0);
	vec4 worldPosition = worldTransform * localPosition;

	fragment.localPosition = localPosition.xyz;
	fragment.worldPosition = worldPosition;
	fragment.position = camera.projectionTransform * camera.viewTransform * worldPosition;
	fragment.localNormal = normalize(mat3(localTransform) * localPosition);
	fragment.normal = normalize(normalTransform * vertex.position);
	fragment.tangent = normalize(normalTransform * vertex.tangent);
	fragment.bitangent = normalize(vec3(vertex.tangent.w) * cross(fragment.normal, fragment.tangent));
	fragment.screenPosition = fragment.position.xyz / fragment.position.w;
	fragment.screenPosition.xy += vec2(1.0);
	fragment.screenPosition.xy *= vec2(0.5);
	fragment.textureCoordinate = vertex.textureCoordinate;
	fragment.color = vertex.color;
	fragment.material = rat_MeshInstance[draw.meshInstance].materialInstanceIndex;
}

void ratVertexDraw(in RatScratchPipelineDraw draw, out RatScratchPipelineFragmentInput fragmentInput, uint vertexIndex)
{
	if (draw.boneOffsetCount.y > 0)
	{
		ratVertexSkinnedDraw(draw, fragmentInput, vertexIndex);
	}
	else
	{
		ratVertexStaticDraw(draw, fragmentInput, vertexIndex);
	}

	ratVertexApplyMaterial(draw, fragmentInput);
}

void vertexmain()
{
	RatScratchPipelineFragmentInput fragmentInput;
	ratClearFragmentInput(fragmentInput);

	ratVertexDraw(rat_Draws[gl_InstanceID], fragmentInput, gl_VertexID);
	ratSetVertexOutputs(fragmentInput);

	gl_Position = fragmentInput;
	// gl_Layer = fragmentInput.layerIndex;
}
