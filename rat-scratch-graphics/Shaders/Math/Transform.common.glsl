mat4 transformCompose(vec3 translation, vec4 rotation, vec3 scale)
{
	float qxx = rotation.x * rotation.x;
	float qyy = rotation.y * rotation.y;
	float qzz = rotation.z * rotation.z;
	float qxz = rotation.x * rotation.z;
	float qxy = rotation.x * rotation.y;
	float qyz = rotation.y * rotation.z;
	float qwx = rotation.w * rotation.x;
	float qwy = rotation.w * rotation.y;
	float qwz = rotation.w * rotation.z;

	float r11 = 1 - 2 * (qyy + qzz);
	float r21 = 2 * (qxy + qwz);
	float r31 = 2 * (qxz - qwy);

	float r12 = 2 * (qxy - qwz);
	float r22 = 1 - 2 * (qxx + qzz);
	float r32 = 2 * (qyz + qwx);

	float r13 = 2 * (qxz + qwy);
	float r23 = 2 * (qyz - qwx);
	float r33 = 1 - 2 * (qxx + qyy);

	return mat4(r11 * scale.x, r21 * scale.x, r31 * scale.x, 0.0,

				r12 * scale.y, r22 * scale.y, r32 * scale.y, 0.0,

				r13 * scale.z, r23 * scale.z, r33 * scale.z, 0.0,

				translation.x, translation.y, translation.z, 1.0);
}
