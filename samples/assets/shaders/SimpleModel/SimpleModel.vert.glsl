#pragma language glsl4

layout(location = 10) in vec3 VertexNormal;

varying vec3 frag_VertexNormal;

vec4 position(mat4 projectionView, vec4 vertexPosition) {
  mat3 normalMatrix = transpose(inverse(mat3(TransformMatrix)));
  frag_VertexNormal = normalize(normalMatrix * VertexNormal);
  return projectionView * vertexPosition;
}