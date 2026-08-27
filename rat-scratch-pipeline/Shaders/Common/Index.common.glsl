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