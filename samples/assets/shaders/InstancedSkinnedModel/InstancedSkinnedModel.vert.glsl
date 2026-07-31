#pragma language glsl4

struct MeshInstance
{
	mat4 worldMatrix;
	uvec2 boneIndexCount;
};

readonly buffer rat_MeshInstancesBuffer
{
	MeshInstance rat_MeshInstances[];
};

readonly buffer rat_MeshInstanceBoneTransformsBuffer
{
	mat4 rat_MeshInstanceBoneTransforms[];
};

layout(location = 10) in vec4 VertexNormal;
layout(location = 20) in uvec4 VertexBoneIndex;
layout(location = 21) in vec4 VertexBoneWeight;

varying vec3 frag_VertexNormal;

vec4 position(mat4 projectionView, vec4 vertexPosition)
{
	MeshInstance meshInstance = rat_MeshInstances[gl_InstanceID];

	vec4 finalPosition = vec4(0.0);
	vec3 finalNormal = vec3(0.0);

	for (int i = 0; i < 4; i++)
	{
		uint boneID = VertexBoneIndex[i];
		float weight = VertexBoneWeight[i];

		if (weight > 0.0)
		{
			mat4 boneMatrix = rat_MeshInstanceBoneTransforms[boneID + meshInstance.boneIndexCount.x];
			finalPosition += boneMatrix * vertexPosition * vec4(weight);
			finalNormal += mat3(boneMatrix) * VertexNormal.xyz * vec3(weight);
		}
	}

	mat3 normalMatrix = transpose(inverse(mat3(TransformMatrix * meshInstance.worldMatrix)));
	frag_VertexNormal = normalize(normalMatrix * finalNormal);

	return projectionView * meshInstance.worldMatrix * finalPosition;
}
