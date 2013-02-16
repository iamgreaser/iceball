#/CMakeLists.txt
cmake_minimum_required (VERSION 2.8)
project (iceball)

#set(CMAKE_BINARY_DIR build)
set(CMAKE_SOURCE_DIR src)
set(OUTDIR ../build)

# First for the generic no-config case (e.g. with mingw)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${OUTDIR} )
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${OUTDIR} )
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${OUTDIR} )
# Second, for multi-config builds (e.g. msvc)
foreach( OUTPUTCONFIG ${CMAKE_CONFIGURATION_TYPES} )
    string( TOUPPER ${OUTPUTCONFIG} OUTPUTCONFIG )
    set( CMAKE_RUNTIME_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${OUTDIR} )
    set( CMAKE_LIBRARY_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${OUTDIR} )
    set( CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${OUTDIR} )
endforeach( OUTPUTCONFIG CMAKE_CONFIGURATION_TYPES )


IF(CMAKE_BUILD_TOOL MATCHES "(msdev|devenv|nmake)")
	add_definitions(/W4)                                        # warning level
	add_definitions(/TP)                                        # compile as c++
ELSEIF(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
	add_definitions(-Wall -g)                                   # keep debugging symbols even in Release builds
ENDIF()

include_directories(include)
if (WIN32)
	if (MSVC)
		set_source_files_properties(filename.c PROPERTIES LANGUAGE CXX )
	endif (MSVC)
	LINK_DIRECTORIES(../winlibs)
	include_directories(winlibs/glew)
	include_directories(winlibs/lua)
	include_directories(winlibs/SDL)
	include_directories(winlibs/zlib)
endif (WIN32)

add_subdirectory(src)
