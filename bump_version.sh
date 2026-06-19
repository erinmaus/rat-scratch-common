#!/bin/sh

rs_meta=${2:-./.rs_meta}

function has_version() {
    echo $1 | sed -n 's/\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/\1/p'
}

function escape_version() {
    echo $1 | sed -n 's/\./\\\./gp'
}

function update_rsmeta_version() {
    spaces_pattern=$'[ \t]*'
    filename=$1
    version=$2

    sed -i .bak "s/version$spaces_pattern=$spaces_pattern.*/version = $(escape_version $version)/g" $filename
    rm $filename.bak
    git add $filename
}

function update_packagejson_version() {
    spaces_pattern=$'[ \t]*'
    filename=$1
    version=$2

    sed -i .bak "s/\"version\":$spaces_pattern\"$spaces_pattern.*spaces_pattern\"/\"version\": \"$(escape_version $version)\"/g" $filename
    rm $filename.bak
    git add $filename
}

version=$(has_version $1)
if [ -z "$version" ]; then
    echo "Need a version in the format major.minor.revision (e.g., 1.0.0)"
    exit 1
fi

has_pending_changes=$(git status --porcelain)

if [ ! -z "$has_pending_changes" ]; then
    echo "Cannot bump version when current directory has pending changes!"
    exit 1
fi

echo rat-scratch get --meta=${rs_meta} name
release_branch="release-$(rat-scratch get --meta=${rs_meta} name)-v${version}"
has_release_branch=$(git rev-parse --verify $release_branch 2> /dev/null)

if [ "$has_release_branch" ]; then
    echo "Delete ${has_release_branch} first then run this command."
    exit 1
fi

if [ -z "RAT_SCRATCH_DRY_RUN" ]; then
    git checkout main
    git pull origin
fi

set -e

git checkout -b $release_branch

if [ ! "${rs_meta}" = "./package.json" ]; then
    update_rsmeta_version "${rs_meta}" $version
fi

if [ "${rs_meta}" = "./.rsmeta" ] || [ "${rs_meta}" = "./package.json" ]; then
    update_packagejson_version "./package.json" $version
fi

npm ci

git commit -m "Bump version to ${version}."

if [ -z "RAT_SCRATCH_DRY_RUN" ]; then
    git push origin
    github_pr_url=$(gh pr create --fill)
else
    github_pr_url=$(gh repo view --json url --template '{{.url}}')
fi

set +e

which xdg-open
if [ $? -eq 0 ]; then
    xdg-open "$github_pr_url"
else
    which open
    if [ $? -eq 0 ]; then
        open "$github_pr_url"
    fi
fi

echo "Bumped version to ${version}. Now do a PR: ${github_pr_url}!"
