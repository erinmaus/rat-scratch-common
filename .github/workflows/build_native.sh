#!/bin/sh

makefiles="$(pwd)/rat-scratch-native/*/Makefile"

set -x

for makefile in ${makefiles}; do
	dir=$(dirname -- "$makefile")

	cd "$dir"
	echo "Building $($RAT_SCRATCH get --meta=./.rsmeta name)..."
	$RAT_SCRATCH bundle --meta=./.rsmeta
	make all -j$(nproc)
done
