cmake_minimum_required (VERSION 3.0)
# "MSYS2 and *nix are first class citizens." the holy arsdragonfly decided.
option(HUNTER_ENABLED "Enable Hunter to grab dependencies on Windows for mingw32-make and MSVC" OFF)
SET(HUNTER_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/hunter")
SET(HUNTER_CONFIGURATION_TYPES Debug)
include("cmake/HunterGate.cmake")
HunterGate(
	URL "https://github.com/ruslo/hunter/archive/v0.20.70.tar.gz"
	SHA1 "95fb7d11f0828746e2983b5f06ff7981a676da3f"
	LOCAL
)
project (iceball)

set(CMAKE_SOURCE_DIR src)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

if (CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
	add_definitions(-fno-strict-aliasing -Wall -Wextra -Og) # keep debugging symbols even in Release builds
endif ()

include_directories(include)
if (WIN32)
	if (MSVC)
		set_source_files_properties(filename.c PROPERTIES LANGUAGE CXX )
	endif (MSVC)
endif (WIN32)


if (MSYS) #MINGW is true on MSYS2, but we do not use hunter
elseif (MINGW OR MSVC) #Use hunter to grab and build dependencies
	hunter_add_package(enet)
	find_package(enet CONFIG REQUIRED)
	hunter_add_package(Lua)
	find_package(Lua CONFIG REQUIRED)
	hunter_add_package(ZLIB)
	find_package(ZLIB CONFIG REQUIRED)
	hunter_add_package(SDL2)
	find_package(SDL2 CONFIG REQUIRED)
endif ()

if (MSYS OR (NOT (MINGW OR MSVC)))
	#Default on MSYS, *nix and OSX
	find_package(ENet REQUIRED)
	find_package(SDL2 REQUIRED)
	find_package(ZLIB REQUIRED)
	find_package(LuaJIT)
	if (LUAJIT_FOUND)
		add_definitions(-DUSE_LUAJIT)
		set(LUA_LIBRARIES ${LUA_LIBRARY} m)
	else ()
		find_package(Lua REQUIRED)
	endif ()
endif ()

find_package(sackit REQUIRED)
find_package(OpenGL REQUIRED)


if (MSYS OR (NOT (MINGW OR MSVC)))
	#Stupid naming inconsistency
	include_directories(
		${ENet_INCLUDE_DIRS}
		${sackit_INCLUDE_DIRS}
		${ZLIB_INCLUDE_DIRS}
		${SDL2_INCLUDE_DIR}
		${LUA_INCLUDE_DIR}
	)
else ()
	include_directories(
		"${ENET_ROOT}/include"
		${sackit_INCLUDE_DIRS}
		"${ZLIB_ROOT}/include"
		"${SDL2_ROOT}/include/SDL2"
		"${LUA_ROOT}/include"
	)
endif ()


file(GLOB LUA_FILES src/lua* src/external/bit.c)
set(MAIN_FILES
	src/dsp.c
	src/img.c
	src/json.c
	src/logtxt.c
	src/main.c
	src/map.c
	src/model.c
	src/network.c
	src/path.c
	src/png.c
	src/random.c
	src/vecmath.c
	src/wav.c
)

set(GL_FILES
	src/gl/glad.c
	src/gl/render.c
	src/gl/render_img.c
)

source_group(gl FILES ${GL_FILES})
source_group(lua FILES ${LUA_FILES})

# iceball target
add_executable(iceball ${MAIN_FILES} ${LUA_FILES} ${GL_FILES})
if (MSYS OR (NOT (MINGW OR MSVC)))
	target_link_libraries(iceball ${CMAKE_DL_LIBS} ${ENet_LIBRARIES} ${ZLIB_LIBRARIES} ${sackit_LIBRARY} ${LUA_LIBRARIES} ${SDL2_LIBRARIES} ${OPENGL_LIBRARIES})
	if (MSYS)
		set_target_properties(iceball PROPERTIES LINK_FLAGS "-mwindows") # Get rid of console
	endif ()
else ()
	if (MINGW)
		set_target_properties(iceball PROPERTIES LINK_FLAGS "-lmingw32")
	endif ()
	target_link_libraries(iceball ${CMAKE_DL_LIBS} ${sackit_LIBRARY} ${OPENGL_LIBRARIES} enet::enet Lua::lua_lib ZLIB::zlib SDL2::SDL2main SDL2::SDL2)
endif ()
set_target_properties(iceball PROPERTIES C_STANDARD 99)

# iceball-dedi target
add_executable(iceball-dedi EXCLUDE_FROM_ALL ${MAIN_FILES} ${LUA_FILES})
if (MSYS OR (NOT (MINGW OR MSVC)))
	target_link_libraries(iceball-dedi ${CMAKE_DL_LIBS} ${ENet_LIBRARIES} ${ZLIB_LIBRARIES} ${LUA_LIBRARIES})
else ()
	target_link_libraries(iceball-dedi ${CMAKE_DL_LIBS} enet::enet Lua::lua_lib ZLIB::zlib)
endif ()
set_target_properties(iceball-dedi PROPERTIES C_STANDARD 99)
set_target_properties(iceball-dedi PROPERTIES COMPILE_DEFINITIONS "DEDI")

function(copy_run_dep arg1)
	add_custom_command(TARGET iceball POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different
			"${arg1}"
			$<TARGET_FILE_DIR:iceball>)
endfunction()
if (MSYS)
	copy_run_dep($ENV{MSYSTEM_PREFIX}/bin/SDL2.dll)
	copy_run_dep($ENV{MSYSTEM_PREFIX}/bin/lua51.dll)
	copy_run_dep($ENV{MSYSTEM_PREFIX}/bin/zlib1.dll)
	copy_run_dep($ENV{MSYSTEM_PREFIX}/bin/libenet-7.dll)
endif ()
