#pragma language glsl4

layout(location = 0) in vec2 VertexPosition;

varying vec2 frag_TextureCoordinate;

void vertexmain()
{
	frag_TextureCoordinate = VertexPosition;
	gl_Position = vec4((VertexPosition.xy - vec2(0.5)) * vec2(2.0), 0.0, 1.0);
	gl_Layer = gl_InstanceID;
}
