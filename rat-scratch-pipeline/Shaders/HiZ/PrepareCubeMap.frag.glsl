#pragma language glsl4

#include "@Pipeline/PostProcess/Common.frag.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Camera.common.glsl"

uniform sampler2DArray rat_DepthTexture;

layout(location = 0) out vec2 rat_Depth;

void pixelmain()
{
	float depthSample = texture(rat_DepthTexture, vec3(frag_TextureCoordinate, gl_Layer)).x;
	vec3 viewPosition = ratScreenPositionToViewPosition(gl_Layer, vec3(frag_TextureCoordinate, depthSample));
	float distanceFromCamera = abs(viewPosition.z);

	rat_Depth = vec2(distanceFromCamera, distanceFromCamera);
}
