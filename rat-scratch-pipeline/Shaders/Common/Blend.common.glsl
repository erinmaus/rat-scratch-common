vec4 alphaBlend(vec4 destination, vec4 source)
{
	vec4 result = destination;

	result.rgb *= vec3(1.0 - source.a);
	result.rgb += vec3(source.a) * source.rgb;
	result.a *= 1.0 - source.a;
	result.a += source.a;

	return result;
}
