#!/bin/sh

VERSION=$(grep -Ei 'str="(.+)"' ../pkg/base/version.lua | grep -oEi '[0-9\.-]+')
VERSION_SHORT=$(echo ${VERSION} | grep -oEi '[^-]*')

cd osx-package-files &&
rm -f Iceball.icns &&
iconutil -c icns -o Iceball.icns Iceball.iconset &&
cd .. &&
rm -rf Iceball.app &&
mkdir -p Iceball.app/Contents/MacOS &&
mkdir -p Iceball.app/Contents/libs &&
mkdir -p Iceball.app/Contents/Resources &&
cp $1 Iceball.app/Contents/MacOS &&
cp osx-package-files/iceball-launcher Iceball.app/Contents/MacOS &&
cp osx-package-files/Info.plist Iceball.app/Contents &&
sed -e "s/@long_version@/${VERSION}/" -e "s/@short_version@/${VERSION_SHORT}/" < osx-package-files/Info.plist > Iceball.app/Contents/Info.plist &&
mv osx-package-files/Iceball.icns Iceball.app/Contents/Resources &&
cp -Rv ../clsave ../dlcache ../docs ../pkg ../svsave ../tools Iceball.app/Contents/MacOS/ &&
dylibbundler -x Iceball.app/Contents/MacOS/$(basename "$1") -b -d Iceball.app/Contents/libs &&
chmod -R 755 Iceball.app/Contents/MacOS/* &&
chmod -R 755 Iceball.app/Contents/libs/*

echo "Iceball"
echo "Version: ${VERSION}"
echo "Short version: ${VERSION_SHORT}"
