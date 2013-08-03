#!/bin/sh
cd osx-package-files
rm -f Iceball.icns
iconutil -c icns -o Iceball.icns Iceball.iconset
cd ..
rm -rf Iceball.app
mkdir -p Iceball.app/Contents/MacOS
mkdir -p Iceball.app/Contents/libs
mkdir -p Iceball.app/Contents/Resources
cp iceball-gl Iceball.app/Contents/MacOS
cp osx-package-files/iceball-launcher Iceball.app/Contents/MacOS
cp osx-package-files/Info.plist Iceball.app/Contents
cp osx-package-files/Iceball.icns Iceball.app/Contents/Resources
cp -Rv clsave dlcache docs pkg svsave tools Iceball.app/Contents/MacOS/
dylibbundler -x Iceball.app/Contents/MacOS/iceball-gl -b -d Iceball.app/Contents/libs
chmod -R 755 Iceball.app/Contents/MacOS/*
chmod -R 755 Iceball.app/Contents/libs/*
