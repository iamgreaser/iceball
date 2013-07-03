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
ECHO 7. Tutorial
ECHO 8. PMF Editor Tutorial
ECHO -------------------------------------
ECHO 0. Exit
ECHO -------------------------------------
ECHO.

SET INPUT=
SET /P INPUT=Please select a number: 

cls
IF /I '%INPUT%'=='1' GOTO SinglePlayer
IF /I '%INPUT%'=='2' GOTO DevServer
IF /I '%INPUT%'=='3' GOTO LightingTest
IF /I '%INPUT%'=='4' GOTO SnowTest
IF /I '%INPUT%'=='5' GOTO MapEditor
IF /I '%INPUT%'=='6' GOTO PMFEditor
IF /I '%INPUT%'=='7' GOTO Tutorial
IF /I '%INPUT%'=='8' GOTO PMFEditorTutorial
IF /I '%INPUT%'=='0' EXIT

ECHO Invalid option
pause
cls
GOTO Menu

:SinglePlayer
ECHO Starting local server...
iceball-gl.exe -s 0 pkg/base pkg/maps/mesa.vxl
ECHO.
cls
GOTO Menu

:DevServer
ECHO Connecting to dev server...
iceball-gl.exe -c play.iceballga.me 20737
ECHO.
cls
GOTO Menu

:LightingTest
ECHO Starting lighting test...
iceball-gl.exe -s 0 pkg/iceball/radtest
ECHO.
cls
GOTO Menu

:SnowTest
ECHO Starting snow weather test...
iceball-gl.exe -s 0 pkg/iceball/snowtest
ECHO.
cls
GOTO Menu

:MapEditor
ECHO Starting map editor...
iceball-gl.exe -s 0 pkg/iceball/mapedit
ECHO.
cls
GOTO Menu

:PMFEditor
ECHO Starting PMF editor...
iceball-gl.exe -s 0 pkg/iceball/pmfedit
ECHO.
cls
GOTO Menu

:Tutorial
ECHO Starting tutorial...
iceball-gl.exe -s 0 pkg/iceball/halp
ECHO.
cls
GOTO Menu

:PMFEditorTutorial
ECHO Starting tutorial...
iceball-gl.exe -s 0 pkg/iceball/pmfedithalp
ECHO.
cls
GOTO Menu