layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

#include "@Generated/Pipeline/Config.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"

layout(r8ui) restrict writeonly uniform uimage2DArray rat_OITABufferCount;

restrict readonly buffer rat_LayersBuffer
{
	uint rat_Layers[];
};

void computemain()
{
	int layer = int(rat_Layers[gl_GlobalInvocationID.z]);

	ivec2 coordinate = ivec2(gl_GlobalInvocationID.xy);
	ivec2 bufferSize = imageSize(rat_OITABufferCount).xy;
	if (coordinate.x < bufferSize.x && coordinate.y < bufferSize.y)
	{
		imageStore(rat_OITABufferCount, ivec3(coordinate, layer), uvec4(0));
	}
}
