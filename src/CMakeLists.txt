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

add_executable(iceded ${MAIN_FILES} ${LUA_FILES})
target_link_libraries(iceded lua5.1 SDL SDLmain)
set_target_properties(iceded PROPERTIES COMPILE_DEFINITIONS "DEDI")

macro(add_dll DLLNAME)
	add_custom_command(TARGET iceball POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_if_different ../winlibs/${DLLNAME} $<TARGET_FILE_DIR:iceball>)
	add_custom_command(TARGET iceball-soft POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_if_different ../winlibs/${DLLNAME} $<TARGET_FILE_DIR:iceball-soft>)
	add_custom_command(TARGET iceded POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_if_different ../winlibs/${DLLNAME} $<TARGET_FILE_DIR:iceball-soft>)
endmacro(add_dll)


if (WIN32)
	target_link_libraries(iceball ws2_32 zdll)
	target_link_libraries(iceball-soft ws2_32 zdll)
	target_link_libraries(iceded ws2_32 zdll)
	add_dll("lua5.1.dll")
	add_dll("SDL.dll")
	add_dll("glew32.dll")
	add_dll("zlib1.dll")
else()
	#target_link_libraries(iceball zlib)
	#target_link_libraries(iceball-soft zlib)
endif (WIN32)