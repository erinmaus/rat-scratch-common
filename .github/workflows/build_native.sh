#!/bin/sh

makefiles=./rat-scratch-native/*/Makefile

for makefile in ${makefiles}; do
	dir=$(dirname -- "$makefile")

	pushd "$dir" > /dev/null
	echo "Building $($RAT_SCRATCH get --meta=./.rsmeta name)..."
	$RAT_SCRATCH bundle --meta=./.rsmeta
	make all -j$(nproc)
	popd > /dev/null
done
