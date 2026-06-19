#!/bin/sh

rs_meta=${1:-./.rs_meta}

function has_version() {
    echo $1 | sed -n 's/\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/\1/p'
}

version=$(has_version $(rat-scratch get --meta=${rs_meta} version))
if [ -z "$version" ]; then
    echo "Need a version in the format major.minor.revision (e.g., 1.0.0)"
    exit 1
fi

has_pending_changes=$(git status --porcelain)

if [ ! -z "$has_pending_changes" ]; then
    echo "Cannot package release when current directory has pending changes!"
    exit 1
fi

tag="$(rat-scratch get --meta=${rs_meta} name)-v${version}"

set -e

if [ -z "RAT_SCRATCH_DRY_RUN" ]; then
    git fetch
    git checkout main
    git pull
    git tag "$tag"
    git push origin tag "$tag"
else
    echo "Dry run - not creating & pushing tag ${tag}."
fi

set +e

zip_file="${tag}.zip"
tar_file="${tag}.tar.gz"

rm -r build lib
rat-scratch build --meta=${rs_meta}
mv build/* build/$(rat-scratch get --meta=${rs_meta} name)

pushd ./build

cp -r .${rs_meta} ../LICENSE ../README.md .
zip -r "../$zip_file" .
tar -czvf "../$tar_file" .

popd

if [ -z "RAT_SCRATCH_DRY_RUN" ]; then
    gh release create --draft --verify-tag -t "$(rat-scratch get --meta=${rs_meta} name) v${version}" "$tag" "./$zip_file" "./$tar_file"
else
    echo "Dry run - not creating GitHub release."
fi
