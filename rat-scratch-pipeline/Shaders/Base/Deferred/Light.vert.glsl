varying vec2 frag_TextureCoordinate;

layout(location = 0) in vec2 VertexPosition;
layout(location = 1) in vec2 VertexTexCoord;

void vertexmain()
{
	frag_TextureCoordinate = VertexTexCoord;

	gl_Position = vec4(VertexPosition, 0.0, 1.0);
}
