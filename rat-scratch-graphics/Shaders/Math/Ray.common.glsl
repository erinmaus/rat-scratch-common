#include "@/Math/Common.common.glsl"

bool intersectRayTriangle(vec3 origin, vec3 direction, vec3 ta, vec3 tb, vec3 tc, out float t, out float side,
						  out vec3 barycentricCoordinates)
{
	vec3 bMinusA = tb - ta;
	vec3 cMinusA = tc - ta;
	vec3 h = cross(direction, cMinusA);
	float a = dot(bMinusA, h);

	if (abs(a) < RAT_SCRATCH_EPSILON)
	{
		return false;
	}

	float f = 1.0 / a;
	vec3 s = origin - ta;
	float u = f * dot(s, h);

	if (u < 0.0 || u > 1.0)
	{
		return false;
	}

	vec3 q = cross(s, bMinusA);
	float v = f * dot(direction, q);

	if (v < 0.0 || u + v > 1.0)
	{
		return false;
	}

	barycentricCoordinates = vec3(1.0 - u - v, u, v);

	side = sign(a);
	t = f * dot(cMinusA, q);

	return t > RAT_SCRATCH_EPSILON;
}

bool intersectRayTriangle(vec3 origin, vec3 direction, vec3 a, vec3 b, vec3 c, out float t, out float side)
{
	vec3 barycentricCoordinates;
	return intersectRayTriangle(origin, direction, a, b, c, t, side, barycentricCoordinates);
}

bool intersectRayTriangle(vec3 origin, vec3 direction, vec3 a, vec3 b, vec3 c, out float t)
{
	float side;
	vec3 barycentricCoordinates;
	return intersectRayTriangle(origin, direction, a, b, c, t, side);
}
