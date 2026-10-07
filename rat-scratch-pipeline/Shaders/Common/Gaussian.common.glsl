const float[3] ratImplGaussianKernel3 = float[3](0.3127719784, 0.3744560432, 0.3127719784);
vec4 ratGaussian3(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(1) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 3; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel3[i]);
	}
	return result;
}
vec4 ratGaussian3(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(1) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 3; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel3[i]);
	}
	return result;
}

const float[5] ratImplGaussianKernel5 = float[5](0.1335747129, 0.2292151240, 0.2744203263, 0.2292151240, 0.1335747129);
vec4 ratGaussian5(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(2) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 5; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel5[i]);
	}
	return result;
}
vec4 ratGaussian5(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(2) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 5; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel5[i]);
	}
	return result;
}

const float[7] ratImplGaussianKernel7 =
	float[7](0.0489867383, 0.1204879339, 0.2067581214, 0.2475344129, 0.2067581214, 0.1204879339, 0.0489867383);
vec4 ratGaussian7(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(3) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 7; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel7[i]);
	}
	return result;
}
vec4 ratGaussian7(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(3) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 7; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel7[i]);
	}
	return result;
}

const float[9] ratImplGaussianKernel9 = float[9](0.0135195690, 0.0476621791, 0.1172300440, 0.2011675600, 0.2408412957,
												 0.2011675600, 0.1172300440, 0.0476621791, 0.0135195690);
vec4 ratGaussian9(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(4) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 9; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel9[i]);
	}
	return result;
}
vec4 ratGaussian9(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(4) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 9; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel9[i]);
	}
	return result;
}

const float[11] ratImplGaussianKernel11 =
	float[11](0.0026612647, 0.0134476107, 0.0474084958, 0.1166060837, 0.2000968398, 0.2395594109, 0.2000968398,
			  0.1166060837, 0.0474084958, 0.0134476107, 0.0026612647);
vec4 ratGaussian11(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(5) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 11; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel11[i]);
	}
	return result;
}
vec4 ratGaussian11(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(5) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 11; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel11[i]);
	}
	return result;
}

const float[13] ratImplGaussianKernel13 =
	float[13](0.0003671690, 0.0026593104, 0.0134377356, 0.0473736819, 0.1165204554, 0.1999499011, 0.2393834933,
			  0.1999499011, 0.1165204554, 0.0473736819, 0.0134377356, 0.0026593104, 0.0003671690);
vec4 ratGaussian13(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(6) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 13; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel13[i]);
	}
	return result;
}
vec4 ratGaussian13(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(6) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 13; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel13[i]);
	}
	return result;
}

const float[15] ratImplGaussianKernel15 = float[15](
	0.0000353660, 0.0003671430, 0.0026591223, 0.0134367851, 0.0473703311, 0.1165122137, 0.1999357582, 0.2393665612,
	0.1999357582, 0.1165122137, 0.0473703311, 0.0134367851, 0.0026591223, 0.0003671430, 0.0000353660);
vec4 ratGaussian15(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(7) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 15; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel15[i]);
	}
	return result;
}
vec4 ratGaussian15(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(7) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 15; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel15[i]);
	}
	return result;
}

const float[17] ratImplGaussianKernel17 =
	float[17](0.0000023768, 0.0000353658, 0.0003671412, 0.0026591097, 0.0134367213, 0.0473701059, 0.1165116598,
			  0.1999348078, 0.2393654234, 0.1999348078, 0.1165116598, 0.0473701059, 0.0134367213, 0.0026591097,
			  0.0003671412, 0.0000353658, 0.0000023768);
vec4 ratGaussian17(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(8) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 17; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel17[i]);
	}
	return result;
}
vec4 ratGaussian17(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(8) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 17; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel17[i]);
	}
	return result;
}

const float[19] ratImplGaussianKernel19 =
	float[19](0.0000001114, 0.0000023768, 0.0000353658, 0.0003671412, 0.0026591091, 0.0134367183, 0.0473700953,
			  0.1165116339, 0.1999347632, 0.2393653700, 0.1999347632, 0.1165116339, 0.0473700953, 0.0134367183,
			  0.0026591091, 0.0003671412, 0.0000353658, 0.0000023768, 0.0000001114);
vec4 ratGaussian19(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(9) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 19; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel19[i]);
	}
	return result;
}
vec4 ratGaussian19(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(9) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 19; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel19[i]);
	}
	return result;
}

const float[21] ratImplGaussianKernel21 =
	float[21](0.0000000036, 0.0000001114, 0.0000023768, 0.0000353658, 0.0003671412, 0.0026591090, 0.0134367182,
			  0.0473700950, 0.1165116330, 0.1999347618, 0.2393653683, 0.1999347618, 0.1165116330, 0.0473700950,
			  0.0134367182, 0.0026591090, 0.0003671412, 0.0000353658, 0.0000023768, 0.0000001114, 0.0000000036);
vec4 ratGaussian21(sampler2D inputTexture, ivec2 direction, ivec2 position, int lod)
{
	position -= ivec2(10) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 21; ++i)
	{
		result += texelFetch(inputTexture, direction * ivec2(i) + position, lod) * vec4(ratImplGaussianKernel21[i]);
	}
	return result;
}
vec4 ratGaussian21(sampler2DArray inputTexture, ivec2 direction, ivec3 position, int lod)
{
	position.xy -= ivec2(10) * direction;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 21; ++i)
	{
		result += texelFetch(inputTexture, ivec3(direction * ivec2(i) + position.xy, position.z), lod) *
				  vec4(ratImplGaussianKernel21[i]);
	}
	return result;
}