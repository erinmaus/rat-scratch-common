const uint RAT_SCRATCH_CUBE_MAP_FACES = 6;

const vec3[] RAT_SCRATCH_CUBE_MAP_NORMALS = vec3[](vec3(1.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0),
												   vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0), );

const vec3 RAT_SRATCH_CUBE_MAP_TANGENTS[6] = vec3[](vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0), vec3(1.0, 0.0, 0.0),
													vec3(1.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0));

const vec3 RAT_SRATCH_CUBE_MAP_BITANGENTS[6] = vec3[](vec3(0.0, -1.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, 1.0),
													  vec3(0.0, 0.0, -1.0), vec3(0.0, -1.0, 0.0), vec3(0.0, -1.0, 0.0));

vec2 ratCubeMapImplDirectionToTextureCoordinate(vec3 direction, uint faceIndex)
{
	float w = abs(dot(direction, RAT_SCRATCH_CUBE_MAP_NORMALS[faceIndex]));

	float s = dot(direction, RAT_SCRATCH_CUBE_MAP_TANGENTS[faceIndex]);
	float t = dot(direction, RAT_SCRATCH_CUBE_MAP_BITANGENTS[faceIndex]);

	return vec2(s, t) / vec2(w) * vec2(0.5) + vec2(0.5);
}

vec4 ratSampleSeamlessCubeArrayLod(sampler2DArray cubeArray, vec3 direction, float lod, uint index)
{
	vec3 dir = safeNormalize(direction);
	float totalWeight = 0.0;
	vec4 accumulatedColor = vec4(0.0);

	for (uint i = 0; i < RAT_SCRATCH_CUBE_MAP_FACES; ++i)
	{
		float weight = max(0.0, dot(dir, RAT_CUBE_MAP_NORMALS[i]));

		if (weight > 0.0)
		{
			vec2 textureCoordinate = ratCubeMapImplDirectionToTextureCoordinate(dir, i);
			vec4 color = textureLod(cubeArray, vec3(textureCoordinate, float(index + i)), lod);

			accumulatedColor += color * weight;
			totalWeight += weight;
		}
	}

	return totalWeight > 0.0 ? (accumulatedColor / totalWeight) : vec4(0.0);
}
