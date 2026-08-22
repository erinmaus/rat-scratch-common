#include "@/Math/Common.common.glsl"

vec3 clampNormal(vec3 normal)
{
	normal += vec3(1.0);
	normal /= vec3(2.0);

	normal *= step(vec3(RAT_SCRATCH_EPSILON), normal);

	normal *= vec3(2.0);
	normal -= vec3(1.0);

	return normalize(normal);
}

vec2 encodeNormal(vec3 normal)
{
	float l = length(normal.xy);
	float d = step(l, 0.0);
	return (normal.xy / vec2(l + d)) * vec2(sqrt((-normal.z + 1.0) / 2.0));
}

vec3 decodeNormal(vec2 encodedNormal)
{
	float l = dot(vec3(encodedNormal, 1.0), vec3(-encodedNormal, 1.0));
	return vec3(encodedNormal * vec2(sqrt(l)), l) * vec3(2.0) - vec3(vec2(0.0), 1.0);
}

vec2 packNormal2(vec3 normal)
{
	return encodeNormal(clampNormal(normal));
}

vec3 unpackNormal2(vec2 packedNormal)
{
	return decodeNormal(packedNormal);
}

vec3 packTangent3(vec4 tangent)
{
	return vec3(encodedNormal(clampNormal(tangent.xyz)), tangent.w);
}

vec4 unpackTangent3(vec3 packedTangent)
{
	return vec4(decodeNormal(packedTangent.xy), packedTangent.z);
}

uvec2 packBoneIndices2(uvec4 packedBoneIndices)
{
	return uvec2(packedBoneIndices.x & 0xFFFF | (packedBoneIndices.y & 0xFFFF) << 16,
				 packedBoneIndices.z & 0xFFFF | (packedBoneIndices.w & 0xFFFF) << 16);
}

uvec4 unpackBoneIndices2(uvec2 packedBoneIndices)
{
	return uvec4(packedBoneIndices.x & 0xFFFF, (packedBoneIndices.x >> 16) & 0xFFFF, packedBoneIndices.y & 0xFFFF,
				 (packedBoneIndices.y >> 16) & 0xFFFF);
}
