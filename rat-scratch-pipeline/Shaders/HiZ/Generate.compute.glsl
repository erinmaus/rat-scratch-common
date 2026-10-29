layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rg32f) restrict readonly uniform image2DArray rat_Source;
layout(rg32f) restrict writeonly uniform image2DArray rat_Destination;

restrict readonly buffer rat_ActiveCamerasBuffer
{
	uint rat_ActiveCameras[];
};

uniform uint rat_ActiveCameraCount;

void computemain()
{
	ivec2 destinationPosition = ivec2(gl_GlobalInvocationID.xy);
	ivec2 destinationSize = imageSize(rat_Destination).xy;

	if (destinationPosition.x >= destinationSize.x || destinationPosition.y >= destinationSize.y)
	{
		return;
	}

	uint activeCameraIndex = gl_GlobalInvocationID.z;
	if (activeCameraIndex >= rat_ActiveCameraCount)
	{
		return;
	}

	int cameraIndex = int(rat_ActiveCameras[activeCameraIndex]);

	ivec2 sourcePosition = ivec2(2) * destinationPosition;
	ivec2 sourceSize = imageSize(rat_Source).xy;

	int columns = 2 + (sourceSize.x & 0x1);
	int rows = 2 + (sourceSize.y & 0x1);

	vec2 minMaxDepth = vec2(0.0);
	for (int x = 0; x < columns; ++x)
	{
		for (int y = 0; y < rows; ++y)
		{
			ivec2 currentSourcePosition = clamp(ivec2(x, y) + sourcePosition, ivec2(0), sourceSize);
			vec2 currentMinMaxDepth = imageLoad(rat_Source, ivec3(currentSourcePosition, cameraIndex)).xy;
			if (x == 0 && y == 0)
			{
				minMaxDepth = currentMinMaxDepth;
			}
			else
			{
				minMaxDepth.x = min(currentMinMaxDepth.x, minMaxDepth.x);
				minMaxDepth.y = max(currentMinMaxDepth.y, minMaxDepth.y);
			}
		}
	}

	imageStore(rat_Destination, ivec3(destinationPosition, cameraIndex), vec4(minMaxDepth, 0.0, 0.0));
}
