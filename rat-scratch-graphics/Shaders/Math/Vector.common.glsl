#include "./Common.common.glsl"

vec4 safeNormalize(vec4 value) {
  float valueLength = length(value);
  float inverseValueLength = 1.0 / max(valueLength, RAT_EPSILON);
  return value * vec4(inverseValueLength);
}

vec3 safeNormalize(vec3 value) {
  float valueLength = length(value);
  float inverseValueLength = 1.0 / max(valueLength, RAT_EPSILON);
  return value * vec3(inverseValueLength);
}

vec2 safeNormalize(vec2 value) {
  float valueLength = length(value);
  float inverseValueLength = 1.0 / max(valueLength, RAT_EPSILON);
  return value * vec2(inverseValueLength);
}