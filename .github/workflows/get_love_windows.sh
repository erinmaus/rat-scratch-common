#!/bin/sh

./.github/workflows/get_love.sh "love-windows-x64"

cd ./bin
unzip "love-windows-x64.zip"
rm -f love-*.exe
unzip "love-12.0-win64.zip"
cp -r love-12.0-win64/* .
