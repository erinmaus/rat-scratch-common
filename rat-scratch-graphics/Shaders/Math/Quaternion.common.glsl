vec4 quaternionIdentity()
{
	return vec4(vec3(0.0), 1.0);
}

vec4 quaternionSlerp(vec4 self, vec4 other, float t)
{
	float delta = clamp(t, 0.0, 1.0);

	float d = dot(self, other);
	float theta = acos(d);
	float sine = sin(1.0 - theta * theta);

	float c1 = 0.0;
	float c2 = 0.0;
	if (theta > 0.0)
	{
		c1 = sin((1.0 - delta) * theta) / sine;
		c2 = sin(delta * theta) / sine;
	}
	else
	{
		c1 = 1.0 - delta;
		c2 = delta;
	}

	return self * vec4(c1) + other * vec4(c2) * sign(d);
}

vec4 quaternionFromAxisAngle(vec3 axis, float angle)
{
	float halfHangle = angle / 2.0;
	float halfAngleSine = sin(halfHangle);
	float halfAngleCosine = cos(halfHangle);

	return vec4(vec3(halfAngleSine) * axis, halfAngleCosine);
}

vec4 quaternionFromNormals(vec3 u, vec3 v)
{
	float d = dot(normalize(u), normalize(v));
	float halfCos = sqrt(0.5 * (1.0 + d));
	float halfSin = sqrt(0.5 * (1.0 - d));
	vec3 c = normalize(cross(u, v));
	return vec4(c * vec3(halfSin), halfCos);
}

vec4 quaternionLookAt(vec3 source, vec3 target, vec3 up)
{
	vec3 forward = normalize(target - source);
	float d = dot(forward, up);
	float angle = acos(d);
	vec3 axis = normalize(cross(up, forward));
	return quaternionFromAxisAngle(axis, angle);
}

vec4 quaternionConjugate(vec4 value)
{
	return normalize(vec4(-value.xyz, value.w));
}

vec4 quaternionMultiply(vec4 a, vec4 b)
{
	vec4 result = vec4(0.0);

	result.x = a.x * b.w + a.y * b.z - a.z * b.y + a.w * b.x;
	result.y = -a.x * b.z + a.y * b.w + a.z * b.x + a.w * b.y;
	result.z = a.x * b.y - a.y * b.x + a.z * b.w + a.w * b.z;
	result.w = -a.x * b.x - a.y * b.y - a.z * b.z + a.w * b.w;

	return result;
}

mat4 quaternionToMatrix(vec4 value)
{
	float qxx = value.x * value.x;
	float qyy = value.y * value.y;
	float qzz = value.z * value.z;
	float qxz = value.x * value.z;
	float qxy = value.x * value.y;
	float qyz = value.y * value.z;
	float qwx = value.w * value.x;
	float qwy = value.w * value.y;
	float qwz = value.w * value.z;

	float r11 = 1 - 2 * (qyy + qzz);
	float r21 = 2 * (qxy + qwz);
	float r31 = 2 * (qxz - qwy);

	float r12 = 2 * (qxy - qwz);
	float r22 = 1 - 2 * (qxx + qzz);
	float r32 = 2 * (qyz + qwx);

	float r13 = 2 * (qxz + qwy);
	float r23 = 2 * (qyz - qwx);
	float r33 = 1 - 2 * (qxx + qyy);

	return mat4(r11, r21, r31, 0.0,

				r12, r22, r32, 0.0,

				r13, r23, r33, 0.0,

				0.0, 0.0, 0.0, 1.0);
}

vec4 quaternionTransformVector(vec4 quaternion, vec4 position)
{
	quaternion = normalize(quaternion);

	return quaternionMultiply(quaternionMultiply(quaternion, position), quaternionConjugate(quaternion));
}
