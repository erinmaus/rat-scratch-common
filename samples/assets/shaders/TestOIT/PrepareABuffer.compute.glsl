layout(local_size_x = 8, local_size_y = 8) in;

layout(r32i) restrict writeonly uniform iimage2D rat_ABufferImage;

void computemain()
{
	ivec2 coordinate = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(rat_ABufferImage);
	if (!(coordinate.x < size.x && coordinate.y < size.y))
	{
		return;
	}

	imageStore(rat_ABufferImage, coordinate, ivec4(-1, 0, 0, 0));
}
