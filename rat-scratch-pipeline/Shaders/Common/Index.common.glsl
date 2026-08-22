uvec2 coordinateToIndex(uvec2 coordinate, uvec2 dimension)
{
	return coordinate.x + (coordinate.y * dimension.x);
}

uvec3 coordinateToIndex(uvec3 coordinate, uvec3 dimension)
{
	return coordinate.x + (coordinate.y * dimension) + (coordinate.z * dimension.x * dimension.y);
}

uvec4 coordinateToIndex(uvec4 coordinate, uvec4 dimension)
{
	return coordinate.x + (coordinate.y * dimension) + (coordinate.z * dimension.x * dimension.y) +
		   (coordinate.w * dimensions.x * dimensions.y * dimensions.z);
}