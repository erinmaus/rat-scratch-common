const vec3 SIMPLE_DIRECTIONAL_LIGHT = vec3(1.0, 2.5, 1.0);

varying vec3 frag_VertexNormal;

vec4 effect(vec4 color, Image image, vec2 textureCoordinates,
            vec2 screenCoordinates) {
  vec3 lightNormal = normalize(SIMPLE_DIRECTIONAL_LIGHT);
  vec4 lightDotSurface =
      vec4(vec3(max(dot(lightNormal, frag_VertexNormal), 0.5)), 1.0);
  return color * lightDotSurface;
}