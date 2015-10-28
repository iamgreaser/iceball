#/CMakeLists.txt
cmake_minimum_required (VERSION 2.8.4)
project (iceball)

#set(CMAKE_BINARY_DIR build)
set(CMAKE_SOURCE_DIR src)
set(OUTDIR ../build)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

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

	include_directories("${CMAKE_CURRENT_SOURCE_DIR}/winlibs")
	include_directories("${CMAKE_CURRENT_SOURCE_DIR}/winlibs/glew")
	include_directories("${CMAKE_CURRENT_SOURCE_DIR}/winlibs/lua")
	include_directories("${CMAKE_CURRENT_SOURCE_DIR}/winlibs/SDL")
	include_directories("${CMAKE_CURRENT_SOURCE_DIR}/winlibs/zlib")
	
	link_directories("${CMAKE_CURRENT_SOURCE_DIR}/winlibs")

endif (WIN32)

# here be sackit
link_directories("${CMAKE_CURRENT_SOURCE_DIR}/xlibinc")
include_directories("${CMAKE_CURRENT_SOURCE_DIR}/xlibinc")

# find the hidden treasures
find_package(ENet REQUIRED)
find_package(PNG REQUIRED)
find_package(SDL2 REQUIRED)
find_package(zlib REQUIRED)
find_package(Lua REQUIRED)
find_package(GLEW REQUIRED)
find_package(OpenGL REQUIRED)

# include the outcasts
include_directories(
    ${PNG_INCLUDE_DIRS}
    ${ENet_INCLUDE_DIRS}
    ${SACKIT_INCLUDE_DIR}
    ${ZLIB_INCLUDE_DIRS}
    ${GLEW_INCLUDE_DIRS}
    ${SDL2_INCLUDE_DIR}
    ${LUA_INCLUDE_DIR}
)

add_subdirectory(src)
