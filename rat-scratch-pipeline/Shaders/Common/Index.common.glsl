uint coordinateToIndex(uvec2 coordinate, uvec2 dimension)
{
	return coordinate.x + (coordinate.y * dimension.x);
}

uint coordinateToIndex(uvec3 coordinate, uvec3 dimension)
{
	return coordinate.x + (coordinate.y * dimension.x) + (coordinate.z * dimension.x * dimension.y);
}

uint coordinateToIndex(uvec4 coordinate, uvec4 dimension)
{
	return coordinate.x + (coordinate.y * dimension.x) + (coordinate.z * dimension.x * dimension.y) +
		   (coordinate.w * dimension.x * dimension.y * dimension.z);
}

uvec2 indexToCoordinate(uint index, uvec2 dimension)
{
	return uvec2(index % dimension.x, index / dimension.x);
}

uvec3 indexToCoordinate(uint index, uvec3 dimension)
{
	uint x = index % dimension.x;
	uint remainder = index / dimension.x;
	uint y = remainder % dimension.y;
	return uvec3(x, y, remainder / dimension.y);
}

uvec4 indexToCoordinate(uint index, uvec4 dimension)
{
	uint x = index % dimension.x;
	uint remainder = index / dimension.x;
	uint y = remainder % dimension.y;
	remainder = remainder / dimension.y;
	uint z = remainder % dimension.z;
	return uvec4(x, y, z, remainder / dimension.z);
}
