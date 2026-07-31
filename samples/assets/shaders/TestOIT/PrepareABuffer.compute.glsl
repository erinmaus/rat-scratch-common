layout(local_size_x = 64) in;

restrict buffer rat_ABufferBuffer
{
	int rat_ABuffer[];
};

uniform uint rat_ABufferCount;

void computemain()
{
	uint index = gl_GlobalInvocationID.x;
	if (index >= rat_ABufferCount)
	{
		return;
	}

	rat_ABuffer[index] = -1;
}
