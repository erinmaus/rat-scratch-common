void cartesianToBarycentric(vec3 p, vec3 a, vec3 b, vec3 c, out vec3 barycentricCoordinates)
{
	vec3 pMinusC = p - c;
	vec3 bMinusC = b - c;
	vec3 aMinusC = a - c;
	vec3 normal = cross(aMinusC, bMinusC);
	float areaSquaredReciprocal = 1.0 / dot(normal, normal);

	barycentricCoordinates.s = dot(normal, cross(pMinusC, bMinusC)) * areaSquaredReciprocal;
	barycentricCoordinates.t = dot(normal, cross(aMinusC, pMinusC)) * areaSquaredReciprocal;
	barycentricCoordinates.p = 1.0 - barycentricCoordinates.s - barycentricCoordinates.t;
}

vec3 barycentricToCartesian(vec3 barycentricCoordinates, vec3 a, vec3 b, vec3 c)
{
	return vec3(barycentricCoordinates.s) * a + vec3(barycentricCoordinates.t) * b + vec3(barycentricCoordinates.p) * c;
}

vec2 barycentricToCartesian(vec3 barycentricCoordinates, vec2 a, vec2 b, vec2 c)
{
	return vec2(barycentricCoordinates.s) * a + vec2(barycentricCoordinates.t) * b + vec2(barycentricCoordinates.p) * c;
}
