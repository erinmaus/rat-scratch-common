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
	normal /= vec3(abs(normal.x) + abs(normal.y) + abs(normal.z));
	if (normal.z < 0.0)
	{
		vec2 s = vec2(1.0);
		if (normal.x < 0)
		{
			s.x = -1;
		}
		if (normal.y < 0)
		{
			s.y = -1;
		}

		normal.xy = (vec2(1.0) - abs(normal.yx)) * s;
	}

	normal.xy /= vec2(0.5);
	normal.xy += vec2(0.5);

	return normal.xy;
}

vec3 decodeNormal(vec2 encodedNormal)
{
	encodedNormal *= vec2(2.0);
	encodedNormal -= vec2(1.0);

	vec3 result = vec3(encodedNormal.x, encodedNormal.y, 1.0 - abs(encodedNormal.x) - abs(encodedNormal.y));
	vec2 t = vec2(clamp(-result.z, 0.0, 1.0));
	if (encodedNormal.x >= 0)
	{
		t.x = -t.x;
	}
	if (encodedNormal.y >= 0)
	{
		t.y = -t.y;
	}

	result.xy += t;

	return normalize(result);
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
	return vec3(encodeNormal(clampNormal(tangent.xyz)), tangent.w);
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
