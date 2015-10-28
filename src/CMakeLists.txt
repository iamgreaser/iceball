#/src/CMakeLists.txt

file(GLOB LUA_FILES lua*)
set(MAIN_FILES dsp.c img.c json.c logtxt.c main.c map.c model.c network.c path.c vecmath.c wav.c png.c)

set(GL_FILES gl/render.c gl/render_img.c)
source_group(gl FILES ${GL_FILES})

set(SOFT_FILES softgm/render.c softgm/render_img.c)
source_group(softgm FILES ${SOFT_FILES})
source_group(lua FILES ${LUA_FILES})

# iceball target
add_executable(iceball ${MAIN_FILES} ${LUA_FILES} ${GL_FILES})
target_link_libraries(iceball ${PNG_LIBRARIES} ${ENet_LIBRARIES} sackit ${LUA_LIBRARIES} ${SDL2_LIBRARY} ${OPENGL_LIBRARIES} ${GLEW_LIBRARIES})
set_target_properties(iceball PROPERTIES COMPILE_DEFINITIONS "USE_OPENGL")

# iceball-dedi target
add_executable(iceball-dedi EXCLUDE_FROM_ALL ${MAIN_FILES} ${LUA_FILES})
target_link_libraries(iceball-dedi ${PNG_LIBRARIES} ${ENet_LIBRARIES} ${LUA_LIBRARIES} ${SDL_LIBRARY})
set_target_properties(iceball-dedi PROPERTIES COMPILE_DEFINITIONS "DEDI")
