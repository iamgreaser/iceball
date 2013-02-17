@echo off
cls
echo Generating Visual Studio 2010 files...
echo .
pushd ..
cmake -Wno-dev -G "Visual Studio 10" .
popd