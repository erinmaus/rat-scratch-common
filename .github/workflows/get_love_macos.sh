#!/bin/sh

./.github/workflows/get_love.sh "love-macos"

cd ./bin
unzip "love-macos.zip"
ditto -x -k love-macos.zip .
ln -s ./love.app/Contents/MacOS/love love

