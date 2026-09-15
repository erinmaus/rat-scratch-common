const uint RAT_SCRATCH_MAX_FRAGMENTS = 16;

const uint RAT_SCRATCH_FRAGMENT_BLEND_MODE_ALPHA = 0;
const uint RAT_SCRATCH_FRAGMENT_BLEND_MODE_ADD = 1;
const uint RAT_SCRATCH_FRAGMENT_BLEND_MODE_MULTIPLY = 2;

struct RatScratchABufferFragment
{
	vec4 color;
	float depth;
	uint blendMode;
	int next;
};
