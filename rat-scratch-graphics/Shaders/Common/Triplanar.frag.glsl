#include "@/Common/Wrap.frag.glsl"

struct RatScratchTriplanarTextureCoordinates
{
	vec2 x, y, z;
};

RatScratchTriplanarTextureCoordinates triplanarMap(vec3 modelPosition, vec3 modelNormal)
{
	RatScratchTriplanarTextureCoordinates result;

	result.x = -modelPosition.zy;
	result.y = modelPosition.xz;
	result.z = -modelPosition.xy;

	if (modelNormal.x < 0.0)
	{
		result.x.x = -result.x.x;
	}

	if (modelNormal.y < 0.0)
	{
		result.y.x = -result.y.x;
	}

	if (modelNormal.z > 0.0)
	{
		result.z.x = -result.z.x;
	}

	result.x.x += 0.5;
	result.z.x += 0.5;

	return result;
}

vec3 triplanarWeights(vec3 modelNormal, float offset, float exponent)
{
	vec3 w = pow(clamp(abs(modelNormal) - vec3(offset), vec3(0.0), vec3(1.0)), vec3(exponent));
	return w / (w.x + w.y + w.z);
}

vec4 sampleTriplanar(sampler2D image, RatScratchTriplanarTextureCoordinates triplanarTextureCoordinates, vec3 weight,
					 float scale, vec2 st, vec2 wh)
{
	vec4 x = texture(image, textureCoordinateWrap((triplanarTextureCoordinates.x * vec2(scale))) * wh + st) * weight.x;
	vec4 y = texture(image, textureCoordinateWrap((triplanarTextureCoordinates.y * vec2(scale))) * wh + st) * weight.y;
	vec4 z = texture(image, textureCoordinateWrap((triplanarTextureCoordinates.z * vec2(scale))) * wh + st) * weight.z;

	return x + y + z;
}

vec4 sampleTriplanar(sampler2D image, RatScratchTriplanarTextureCoordinates triplanarTextureCoordinates, vec3 weight,
					 float scale)
{
	sampleTriplanar(image, triplanarTextureCoordinates, weight, scale, vec2(0.0), vec2(1.0));
}

vec4 sampleTriplanarArray(sampler2DArray image, RatScratchTriplanarTextureCoordinates triplanarTextureCoordinates,
						  vec3 weight, float scale, vec2 st, vec2 wh, float layer)
{
	vec4 x = texture(image, vec3(textureCoordinateWrap(triplanarTextureCoordinates.x * vec2(scale)) * wh + st, layer)) *
			 weight.x;
	vec4 y = texture(image, vec3(textureCoordinateWrap(triplanarTextureCoordinates.y * vec2(scale)) * wh + st, layer)) *
			 weight.y;
	vec4 z = texture(image, vec3(textureCoordinateWrap(triplanarTextureCoordinates.z * vec2(scale)) * wh + st, layer)) *
			 weight.z;

	return x + y + z;
}

vec4 sampleTriplanarArray(sampler2D image, RatScratchTriplanarTextureCoordinates triplanarTextureCoordinates,
						  vec3 weight, float scale, float layer)
{
	sampleTriplanarArray(image, triplanarTextureCoordinates, weight, scale, vec2(0.0), vec2(1.0), layer);
}
