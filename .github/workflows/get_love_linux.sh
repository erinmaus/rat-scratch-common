#!/bin/sh

./.github/workflows/get_love.sh "love-linux-X64.AppImage"

cd ./bin
unzip "love-linux-X64.AppImage.zip"
mv love-*.AppImage ./love
chmod +x ./love
