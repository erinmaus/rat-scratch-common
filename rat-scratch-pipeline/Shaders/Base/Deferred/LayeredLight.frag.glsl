#pragma language glsl4

#define ratTextureCoordinateType vec3
#define ratGBufferSamplerBufferType sampler2DArray
#define uratGBufferSamplerBufferType usampler2DArray

varying uint frag_CameraIndex;
#define RAT_CAMERA_INDEX frag_CameraIndex

#include "@Pipeline/Base/Deferred/Light.common.glsl"
