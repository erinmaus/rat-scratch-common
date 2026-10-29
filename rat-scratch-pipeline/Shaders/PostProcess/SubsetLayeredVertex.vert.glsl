#pragma language glsl4

layout(location = 0) in vec2 VertexPosition;

varying vec2 frag_TextureCoordinate;

restrict readonly buffer rat_LayersBuffer
{
	uint rat_Layers[];
};

void vertexmain()
{
	vec2 textureCoordinate = VertexPosition;
	textureCoordinate.y = 1.0 - textureCoordinate.y;
	frag_TextureCoordinate = textureCoordinate;

	gl_Position = vec4((VertexPosition.xy - vec2(0.5)) * vec2(2.0), 0.0, 1.0);
	gl_Layer = int(rat_Layers[gl_InstanceID]);
}
