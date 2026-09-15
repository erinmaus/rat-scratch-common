uniform vec3 rat_LightDirection;
uniform sampler2D rat_NormalImage;

varying vec3 frag_VertexNormal;
varying vec3 frag_VertexTangent;
varying vec3 frag_VertexBitangent;

vec4 effect(vec4 color, sampler2D image, vec2 textureCoordinate, vec2 screenCoordinate)
{
	vec3 normalTextureSample = texture(rat_NormalImage, textureCoordinate).xyz;
	normalTextureSample *= vec3(2.0);
	normalTextureSample -= vec3(1.0);

	vec3 t = vec3(normalTextureSample.x) * frag_VertexTangent;
	vec3 b = vec3(normalTextureSample.y) * frag_VertexBitangent;
	vec3 n = vec3(normalTextureSample.z) * frag_VertexNormal;
	vec3 normal = normalize(t + b + n);

	vec3 lightNormal = rat_LightDirection;
	vec4 lightDotSurface = vec4(vec3(clamp(dot(lightNormal, normal), 0.5, 1.0)), 1.0);
	return color * lightDotSurface * texture(image, textureCoordinate);
}