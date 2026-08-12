RAT_SCRATCH_BUILD_DIR := bin

MSYS_VERSION := $(if $(findstring Msys, $(shell uname -o)),$(word 1, $(subst ., ,$(shell uname -r))),0)

ifneq ($(MSYS_VERSION),0)
	RAT_SCRATCH_SHARED_LIB_EXT := dll
	RAT_SCRATCH_STATIC_LIB_EXT := a
	LDFLAGS += -shared
	CPPFLAGS += -DRAT_SCRATCH_WINDOWS
else
	ifeq ($(shell uname),Darwin)
		RAT_SCRATCH_SHARED_LIB_EXT := dylib
		RAT_SCRATCH_STATIC_LIB_EXT := a
		CFLAGS += -arch x86_64 -arch arm64
		CXXFLAGS += -arch x86_64 -arch arm64
		LDFLAGS += -arch x86_64 -arch arm64 -dynamiclib
	else
		RAT_SCRATCH_SHARED_LIB_EXT := so
		RAT_SCRATCH_STATIC_LIB_EXT := a
		CFLAGS += -fPIC
		CXXFLAGS += -fPIC
		LDFLAGS += -shared -fPIC
	endif
endif

ifeq ($(BUILD),DEBUG)
	CFLAGS += -g3 -O0
	CXXFLAGS += -g3 -O0
else
	CFLAGS += -O3
	CXXFLAGS += -O3
endif

OBJ = $(FILES:%.c=$(RAT_SCRATCH_BUILD_DIR)/%.o)
DEP = $(OBJ:%.o=%.d)
BIN = $(shell $(RAT_SCRATCH) get --meta=./.rsmeta name).$(RAT_SCRATCH_SHARED_LIB_EXT)

-include $(DEP)

$(RAT_SCRATCH_BUILD_DIR):
	echo $(OBJ)
	mkdir -p $(RAT_SCRATCH_BUILD_DIR)

$(RAT_SCRATCH_BUILD_DIR)/%.o: %.c $(RAT_SCRATCH_BUILD_DIR)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CPPFLAGS) -MMD -c $< -o $@
	touch $@

$(RAT_SCRATCH_BUILD_DIR)/%.o: %.cpp $(RAT_SCRATCH_BUILD_DIR)
	mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -MMD -c $< -o $@
	touch $@

$(RAT_SCRATCH_BUILD_DIR)/$(BIN): $(OBJ)
	$(CC) $(LDFLAGS) $^ -o $@

all: $(RAT_SCRATCH_BUILD_DIR) $(RAT_SCRATCH_BUILD_DIR)/$(BIN)

clean:
	rm -rf build
