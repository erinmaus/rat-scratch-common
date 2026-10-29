const uint RAT_SCRATCH_CUBE_MAP_FACES = 6;

const vec3[] RAT_SCRATCH_CUBE_MAP_NORMALS = vec3[](vec3(1.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0),
												   vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0));

const vec3[] RAT_SCRATCH_CUBE_MAP_TANGENTS = vec3[](vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0), vec3(-1.0, 0.0, 0.0),
													vec3(-1.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0));

const vec3[] RAT_SCRATCH_CUBE_MAP_BITANGENTS = vec3[](vec3(0.0, -1.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, 1.0),
													  vec3(0.0, 0.0, -1.0), vec3(0.0, -1.0, 0.0), vec3(0.0, -1.0, 0.0));

const uint RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_X = 0;
const uint RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_X = 1;
const uint RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_Y = 2;
const uint RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_Y = 3;
const uint RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_Z = 4;
const uint RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_Z = 5;

uint ratCalculateCubeMapFace(vec3 direction)
{
	vec3 absoluteDirection = abs(direction);
	bvec3 positiveAxis = greaterThanEqual(direction, vec3(0.0));

	if (absoluteDirection.x >= absoluteDirection.y && absoluteDirection.x >= absoluteDirection.z)
	{
		if (positiveAxis.x)
		{
			return RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_X;
		}

		return RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_X;
	}

	if (absoluteDirection.y >= absoluteDirection.x && absoluteDirection.y >= absoluteDirection.z)
	{
		if (positiveAxis.y)
		{
			return RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_Y;
		}

		return RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_Y;
	}

	if (positiveAxis.z)
	{
		return RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_Z;
	}

	return RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_Z;
}

void ratCalculateCubeMapFaceTextureCoordinate(vec3 direction, out uint faceIndex, out vec2 textureCoordinate)
{
	vec3 absoluteDirection = abs(direction);
	bvec3 positiveAxis = greaterThanEqual(direction, vec3(0.0));

	float maxAxisValue = max(absoluteDirection.x, max(absoluteDirection.y, absoluteDirection.z));
	if (absoluteDirection.x >= absoluteDirection.y && absoluteDirection.x >= absoluteDirection.z)
	{
		if (positiveAxis.x)
		{
			faceIndex = RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_X;
			textureCoordinate = vec2(direction.z, -direction.y);
		}
		else
		{
			faceIndex = RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_X;
			textureCoordinate = vec2(-direction.z, -direction.y);
		}
	}
	else if (absoluteDirection.y >= absoluteDirection.x && absoluteDirection.y >= absoluteDirection.z)
	{
		if (positiveAxis.y)
		{
			faceIndex = RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_Y;
			textureCoordinate = vec2(-direction.x, direction.z);
		}
		else
		{
			faceIndex = RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_Y;
			textureCoordinate = vec2(-direction.x, -direction.z);
		}
	}
	else
	{
		if (positiveAxis.z)
		{
			faceIndex = RAT_SCRATCH_CUBE_MAP_FACE_POSITIVE_Z;
			textureCoordinate = vec2(-direction.x, -direction.y);
		}
		else
		{
			faceIndex = RAT_SCRATCH_CUBE_MAP_FACE_NEGATIVE_Z;
			textureCoordinate = vec2(direction.x, -direction.y);
		}
	}

	textureCoordinate /= vec2(maxAxisValue);
	textureCoordinate += vec2(1.0);
	textureCoordinate /= vec2(2.0);
}

vec3 ratCalculateCubeMapCoordinateFromFaceTextureCoordinate(uint faceIndex, vec2 textureCoordinate)
{
	textureCoordinate *= vec2(2.0);
	textureCoordinate -= vec2(1.0);

	vec3 coordinate = RAT_SCRATCH_CUBE_MAP_NORMALS[faceIndex] +
					  textureCoordinate.x * RAT_SCRATCH_CUBE_MAP_TANGENTS[faceIndex] +
					  textureCoordinate.y * RAT_SCRATCH_CUBE_MAP_BITANGENTS[faceIndex];
	return coordinate;
}

vec3 ratCalculateCubeMapNormalFromFaceTextureCoordinate(uint faceIndex, vec2 textureCoordinate)
{
	return normalize(ratCalculateCubeMapCoordinateFromFaceTextureCoordinate(faceIndex, textureCoordinate));
}

vec3 ratCalculateCubeMapBoxPositionFromFaceTextureCoordinate(uint face, vec2 textureCoordinate,
															 float distanceFromPosition, vec3 position)
{
	return ratCalculateCubeMapCoordinateFromFaceTextureCoordinate(face, textureCoordinate) * distanceFromPosition +
		   position;
}

vec3 ratCalculateCubeMapSpherePositionFromFaceTextureCoordinate(uint face, vec2 textureCoordinate,
																float distanceFromPosition, vec3 position)
{
	return ratCalculateCubeMapNormalFromFaceTextureCoordinate(face, textureCoordinate) * distanceFromPosition +
		   position;
}