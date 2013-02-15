#/src/CMakeLists.txt

file(GLOB LUA_FILES lua*)
set(MAIN_FILES dsp.c img.c json.c logtxt.c main.c map.c model.c network.c path.c vecmath.c wav.c)

set(GL_FILES gl/render.c gl/render_img.c)
source_group(gl FILES ${GL_FILES})

set(SOFT_FILES softgm/render.c softgm/render_img.c)
source_group(softgm FILES ${SOFT_FILES})

source_group(lua FILES ${LUA_FILES})

add_executable(iceball ${MAIN_FILES} ${LUA_FILES} ${GL_FILES})
target_link_libraries(iceball lua5.1 SDL SDLmain opengl32 glew32)
set_target_properties(iceball PROPERTIES COMPILE_DEFINITIONS "USE_OPENGL")

add_executable(iceball-soft ${MAIN_FILES} ${LUA_FILES} ${SOFT_FILES})
target_link_libraries(iceball-soft lua5.1 SDL SDLmain)

if (WIN32)
	target_link_libraries(iceball ws2_32 zdll)
	target_link_libraries(iceball-soft ws2_32 zdll)
else()
	#target_link_libraries(iceball zlib)
	#target_link_libraries(iceball-soft zlib)
endif (WIN32)