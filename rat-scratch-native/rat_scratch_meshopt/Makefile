FILES = Main.c

include ../Makefile

CPPFLAGS += -I$(shell pwd)/../../lib/meshoptimizer/src -DMESHOPTIMIZER_API=RAT_SCRATCH_CALLING_CONVENTION
LDFLAGS += $(shell pwd)/../../lib/meshoptimizer/shared/libmeshoptimizer.$(RAT_SCRATCH_SHARED_LIB_EXT)

$(shell pwd)/../../lib: $(shell pwd)/../../.rsmeta
	echo $(CPPFLAGS)
	echo cmake opts $(CMAKE_OPTS)
	$(RAT_SCRATCH) bundle --meta=$(shell pwd)/../../.rsmeta

$(shell pwd)/../../lib/meshoptimizer/shared: $(shell pwd)/../../lib
	cmake -B$(shell pwd)/../../lib/meshoptimizer/shared $(shell pwd)/../../lib/meshoptimizer -DMESHOPT_BUILD_SHARED_LIBS=ON -DMESHOPT_STABLE_EXPORTS=on $(CMAKE_GENERATE_OPTS)

$(shell pwd)/../../lib/meshoptimizer/shared/libmeshoptimizer.$(RAT_SCRATCH_SHARED_LIB_EXT): $(shell pwd)/../../lib/meshoptimizer/shared
	cmake --build $(shell pwd)/../../lib/meshoptimizer/shared $(CMAKE_BUILD_OPTS)

Main.c: $(shell pwd)/../../lib

$(RAT_SCRATCH_BUILD_DIR)/$(BIN): $(shell pwd)/../../lib/meshoptimizer/shared/libmeshoptimizer.$(RAT_SCRATCH_SHARED_LIB_EXT)
