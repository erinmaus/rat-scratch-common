#!/bin/sh

rm -rf ./bin
mkdir -p ./bin

gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  'repos/love2d/love/actions/artifacts' > ./bin/artifacts.json

artifact_name="$1"
artifact_download_url=$(cat ./bin/artifacts.json | jq -r ".artifacts | map(select(.expired != true and .name == \"${artifact_name}\"))[0].archive_download_url")

if [ $? -ne 0 ] || [ -z "$artifact_download_url" ]; then
  echo "Error: could not get latest artifact download URL of type '${artifact_name}'"
  exit 1
fi

echo "Downloading artifact from '${artifact_download_url}' as '${artifact_name}.zip'"

curl -L \
  -H "Authorization: Bearer $(gh auth token)" \
  "${artifact_download_url}" \
  -o "./bin/${artifact_name}.zip"

if [ $? -ne 0 ]; then
  echo "Could not download artifact."
  exit 1
fi
