const float RAT_SCRATCH_PI = 3.1415926535;
const float RAT_SCRATCH_EPSILON = 0.0001;
const float RAT_SCRATCH_INFINITY = 1.0 / 0.0;

bool isNearZero(float value)
{
	return abs(value) <= RAT_SCRATCH_EPSILON;
}

float logb(float value, float base)
{
	return log(value) / log(base);
}
