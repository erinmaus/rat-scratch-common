#extension GL_ARB_shader_viewport_layer_array : enable

varying vec3 frag_TextureCoordinate;

layout(location = 0) in vec2 VertexPosition;
layout(location = 1) in vec2 VertexTexCoord;

void vertexmain()
{
	uint layer = gl_BaseInstance + gl_InstanceID;

	frag_TextureCoordinate = vec3(VertexTexCoord, float(layer));

	gl_Position = vec4(VertexPosition, 0.0, 1.0);
	gl_Layer = layer;
}
