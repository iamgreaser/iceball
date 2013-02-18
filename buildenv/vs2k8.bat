@echo off
cls
echo Generating Visual Studio 2008 files...
echo .
pushd ..
cmake -Wno-dev -G "Visual Studio 9 2008" .
popd