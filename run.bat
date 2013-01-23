@ECHO OFF

:Menu
ECHO ============== Iceball ==============
ECHO -------------------------------------
ECHO 1. Single-player
ECHO 2. Dev server
ECHO 3. Lighting test
ECHO 4. Snow weather test
ECHO 5. Map editor
ECHO 6. PMF editor
ECHO -------------------------------------
ECHO 0. Exit
ECHO -------------------------------------
ECHO.

SET INPUT=
SET /P INPUT=Please select a number: 

IF /I '%INPUT%'=='1' GOTO SinglePlayer
IF /I '%INPUT%'=='2' GOTO DevServer
IF /I '%INPUT%'=='3' GOTO LightingTest
IF /I '%INPUT%'=='4' GOTO SnowTest
IF /I '%INPUT%'=='5' GOTO MapEditor
IF /I '%INPUT%'=='6' GOTO PMFEditor
IF /I '%INPUT%'=='0' EXIT

ECHO Invalid option
GOTO Menu

:SinglePlayer
ECHO Starting local server...
iceball.exe -s 0 pkg/base pkg/maps/mesa.vxl
ECHO.
GOTO Menu

:DevServer
ECHO Connecting to dev server...
iceball.exe -c iceballga.me 20737
ECHO.
GOTO Menu

:LightingTest
ECHO Starting lighting test...
iceball.exe -s 0 pkg/iceball/radtest
ECHO.
GOTO Menu

:SnowTest
ECHO Starting snow weather test...
iceball.exe -s 0 pkg/iceball/snowtest
ECHO.
GOTO Menu

:MapEditor
ECHO Starting map editor...
iceball.exe -s 0 pkg/iceball/mapedit
ECHO.
GOTO Menu

:PMFEditor
ECHO Starting PMF editor...
iceball.exe -s 0 pkg/iceball/pmfedit
ECHO.
GOTO Menu