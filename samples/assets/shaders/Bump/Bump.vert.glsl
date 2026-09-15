#pragma language glsl4

layout(location = 10) in vec3 VertexNormal;
layout(location = 11) in vec4 VertexTangent;

varying vec3 frag_VertexNormal;
varying vec3 frag_VertexTangent;
varying vec3 frag_VertexBitangent;

vec4 position(mat4 projectionView, vec4 vertexPosition)
{
	mat3 normalMatrix = transpose(inverse(mat3(TransformMatrix)));
	frag_VertexNormal = normalize(normalMatrix * VertexNormal);
	frag_VertexTangent = normalize(normalMatrix * VertexTangent.xyz);
	frag_VertexBitangent = normalize(vec3(VertexTangent.w) * cross(frag_VertexNormal, frag_VertexTangent));

	return projectionView * vertexPosition;
}