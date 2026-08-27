#pragma language glsl4

#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Fragment.common.glsl"
#include "@Pipeline/Common/Buffers/Materials.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"

#include "@Generated/Pipeline/Material/Properties.common.glsl"
#include "@Generated/Pipeline/Material/Vertex.vert.glsl"
#include "@Generated/Pipeline/Vertex/Vertex.vert.glsl"

restrict readonly buffer rat_IndicesBuffer
{
	uint rat_Indices[];
};

restrict readonly buffer rat_DrawsBuffer
{
	RatScratchPipelineDraw rat_Draws[];
};

restrict readonly buffer rat_ObjectInstanceBoneTransformsBuffer
{
	mat4 rat_ObjectInstanceBoneTransforms[];
};

const uint RAT_SCRATCH_MAX_BONES_PER_VERTEX = 4;

void ratVertexSkinnedDraw(in RatScratchPipelineDraw draw, out RatScratchPipelineFragmentInput fragment,
						  uint indexOffset)
{
	RatScratchPipelineCamera camera = rat_Cameras[draw.cameraIndex];
	uint staticIndex = rat_Indices[draw.indexOffset + indexOffset] + draw.staticBaseVertexOffset;
	uint skinnedIndex = rat_Indices[draw.indexOffset + indexOffset] + draw.skinnedBaseVertexOffset;

	RatScratchPipelineVertex vertex;
	ratGetStaticVertex(vertex, staticIndex);
	ratGetSkinnedVertex(vertex, staticIndex);

	mat4 boneTransform = mat4(0.0);
	for (uint i = 0; i < RAT_SCRATCH_MAX_BONES_PER_VERTEX; ++i)
	{
		uint boneIndex = draw.boneOffsetCount.x + vertex.boneIndex[i];
		float weight = vertex.boneWeight[i];

		if (weight > 0.0)
		{
			boneTransform += rat_ObjectInstanceBoneTransforms[boneIndex] * weight;
		}
	}

	mat4 worldTransform = rat_ObjectInstances[draw.objectInstanceIndex].worldTransform;
	mat4 localTransform = rat_Models[draw.modelIndex].localTransform;
	mat4 boneWorldLocalTransform = worldTransform * localTransform * boneTransform;

	mat3 normalTransform = transpose(inverse(mat3(boneWorldLocalTransform)));
	vec4 transformedPosition = boneWorldLocalTransform * vec4(vertex.position, 1.0);
	vec3 transformedNormal = normalize(normalTransform * vertex.normal);
	vec3 transformedTangent = normalize(normalTransform * vertex.tangent.xyz);

	vec4 localPosition = localTransform * vec4(vertex.position, 1.0);

	fragment.localPosition = localPosition.xyz;
	fragment.worldPosition = transformedPosition.xyz;
	fragment.position = camera.projectionViewTransform * transformedPosition;
	fragment.screenPosition = fragment.position.xyz / vec3(fragment.position.w);
	fragment.screenPosition += vec3(1.0);
	fragment.screenPosition *= vec3(0.5);
	fragment.localNormal = normalize(mat3(localTransform) * vertex.normal);
	fragment.normal = transformedNormal;
	fragment.tangent = transformedTangent;
	fragment.bitangent = normalize(vec3(vertex.tangent.w) * cross(fragment.normal, fragment.tangent));
	fragment.textureCoordinate = vertex.textureCoordinate;
	fragment.color = vertex.color;
	fragment.materialInstance = rat_MeshInstances[draw.meshInstanceIndex].materialInstanceIndex;
}

void ratVertexStaticDraw(in RatScratchPipelineDraw draw, out RatScratchPipelineFragmentInput fragment, uint indexOffset)
{
	RatScratchPipelineCamera camera = rat_Cameras[draw.cameraIndex];
	uint staticIndex = rat_Indices[draw.indexOffset + indexOffset] + draw.staticBaseVertexOffset;

	RatScratchPipelineVertex vertex;
	ratGetStaticVertex(vertex, staticIndex);

	mat4 worldTransform = rat_ObjectInstances[draw.objectInstanceIndex].worldTransform;
	mat4 localTransform = rat_Models[draw.modelIndex].localTransform;
	mat4 worldLocalTransform = worldTransform * localTransform;
	mat3 normalTransform = transpose(inverse(mat3(worldLocalTransform)));

	vec4 localPosition = localTransform * vec4(vertex.position, 1.0);
	vec4 worldPosition = worldTransform * localPosition;

	fragment.localPosition = localPosition.xyz;
	fragment.worldPosition = worldPosition.xyz;
	fragment.position = camera.projectionViewTransform * worldPosition;
	fragment.localNormal = normalize(mat3(localTransform) * fragment.normal);
	fragment.normal = normalize(normalTransform * vertex.position);
	fragment.tangent = normalize(normalTransform * vertex.tangent.xyz);
	fragment.bitangent = normalize(vec3(vertex.tangent.w) * cross(fragment.normal, fragment.tangent));
	fragment.screenPosition = fragment.position.xyz / fragment.position.w;
	fragment.screenPosition.xy += vec2(1.0);
	fragment.screenPosition.xy *= vec2(0.5);
	fragment.textureCoordinate = vertex.textureCoordinate;
	fragment.color = vertex.color;
	fragment.materialInstance = rat_MeshInstances[draw.meshInstanceIndex].materialInstanceIndex;
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

	gl_Position = fragmentInput.position;
	// gl_Layer = fragmentInput.layerIndex;
}
