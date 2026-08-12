#pragma once

#ifdef RAT_SCRATCH_WINDOWS
#define RAT_SCRATCH_API __declspec(dllimport)
#else
#define RAT_SCRATCH_API __attribute__((visibility("default")))
#endif
