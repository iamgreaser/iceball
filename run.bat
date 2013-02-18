@ECHO OFF
:VERS
ECHO ========== Renderer Select ===========
ECHO -------------------------------------
ECHO 1. OpenGL
ECHO 2. Software Renderer
ECHO -------------------------------------
ECHO 0. Exit
ECHO -------------------------------------

SET VERSION=
SET /P VERSION=Please select a number: 

cls
IF /I '%VERSION%'=='1' GOTO MenuGL
IF /I '%VERSION%'=='2' GOTO MenuSoftware
IF /I '%VERSION%'=='0' EXIT

ECHO Invalid option
pause
cls
GOTO VERS

:MenuSoftware
ECHO ============== Iceball ==============
ECHO -------------------------------------
ECHO 1. Single-player
ECHO 2. Dev server
ECHO 3. Lighting test
ECHO 4. Snow weather test
ECHO 5. Map editor
ECHO 6. PMF editor
ECHO -------------------------------------
ECHO 7. Renderer Select
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
IF /I '%INPUT%'=='7' GOTO VERS
IF /I '%INPUT%'=='0' EXIT

ECHO Invalid option
pause
cls
GOTO MenuSoftware

:SinglePlayer
ECHO Starting local server...
iceball.exe -s 0 pkg/base pkg/maps/mesa.vxl
ECHO.
cls
GOTO MenuSoftware

:DevServer
ECHO Connecting to dev server...
iceball.exe -c iceballga.me 20737
ECHO.
cls
GOTO MenuSoftware

:LightingTest
ECHO Starting lighting test...
iceball.exe -s 0 pkg/iceball/radtest
ECHO.
cls
GOTO MenuSoftware

:SnowTest
ECHO Starting snow weather test...
iceball.exe -s 0 pkg/iceball/snowtest
ECHO.
cls
GOTO MenuSoftware

:MapEditor
ECHO Starting map editor...
iceball.exe -s 0 pkg/iceball/mapedit
ECHO.
cls
GOTO MenuSoftware

:PMFEditor
ECHO Starting PMF editor...
iceball.exe -s 0 pkg/iceball/pmfedit
ECHO.
cls
GOTO MenuSoftware

:MenuGL
ECHO ============= Iceball-GL =============
ECHO -------------------------------------
ECHO 1. Single-player
ECHO 2. Dev server
ECHO 3. Lighting test
ECHO 4. Snow weather test
ECHO 5. Map editor
ECHO 6. PMF editor
ECHO -------------------------------------
ECHO 7. Renderer Select
ECHO -------------------------------------
ECHO 0. Exit
ECHO -------------------------------------
ECHO.

SET GL=
SET /P GL=Please select a number: 

cls
IF /I '%GL%'=='1' GOTO SinglePlayerGL
IF /I '%GL%'=='2' GOTO DevServerGL
IF /I '%GL%'=='3' GOTO LightingTestGL
IF /I '%GL%'=='4' GOTO SnowTestGL
IF /I '%GL%'=='5' GOTO MapEditorGL
IF /I '%GL%'=='6' GOTO PMFEditorGL
IF /I '%GL%'=='7' GOTO VERS
IF /I '%GL%'=='0' EXIT

ECHO Invalid option
pause
cls
GOTO MenuGL

:SinglePlayerGL
ECHO Starting local server...
iceball-gl.exe -s 0 pkg/base pkg/maps/mesa.vxl
ECHO.
cls
GOTO MenuGL

:DevServerGL
ECHO Connecting to dev server...
iceball-gl.exe -c iceballga.me 20737
ECHO.
cls
GOTO MenuGL

:LightingTestGL
ECHO Starting lighting test...
iceball-gl.exe -s 0 pkg/iceball/radtest
ECHO.
cls
GOTO MenuGL

:SnowTestGL
ECHO Starting snow weather test...
iceball-gl.exe -s 0 pkg/iceball/snowtest
ECHO.
cls
GOTO MenuGL

:MapEditorGL
ECHO Starting map editor...
iceball-gl.exe -s 0 pkg/iceball/mapedit
ECHO.
cls
GOTO MenuGL

:PMFEditorGL
ECHO Starting PMF editor...
iceball-gl.exe -s 0 pkg/iceball/pmfedit
ECHO.
cls
GOTO MenuGL