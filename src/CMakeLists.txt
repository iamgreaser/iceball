#/src/CMakeLists.txt

file(GLOB LUA_FILES lua*)
set(MAIN_FILES dsp.c img.c json.c logtxt.c main.c map.c model.c network.c path.c vecmath.c wav.c png.c)

set(GL_FILES gl/render.c gl/render_img.c)
source_group(gl FILES ${GL_FILES})

set(SOFT_FILES softgm/render.c softgm/render_img.c)
source_group(softgm FILES ${SOFT_FILES})
source_group(lua FILES ${LUA_FILES})

# look for required libraries
find_package(ENet REQUIRED)
find_package(PNG REQUIRED)
find_package(SDL REQUIRED)
find_package(zlib REQUIRED)
find_package(Lua REQUIRED)
find_package(GLEW REQUIRED)
find_package(OpenGL REQUIRED)

# here be sackit
link_directories("${CMAKE_CURRENT_SOURCE_DIR}/../xlibinc")
include_directories("${CMAKE_CURRENT_SOURCE_DIR}/../xlibinc")

# include
include_directories(
    ${PNG_INCLUDE_DIRS}
    ${ENet_INCLUDE_DIRS}
    ${SACKIT_INCLUDE_DIR}
    ${ZLIB_INCLUDE_DIRS}
    ${GLEW_INCLUDE_DIRS}
    ${SDL_INCLUDE_DIR}
    ${LUA_INCLUDE_DIR}
)

# iceball-dedi target
add_executable(iceball-dedi EXCLUDE_FROM_ALL ${MAIN_FILES} ${LUA_FILES})
target_link_libraries(iceball-dedi ${PNG_LIBRARIES} ${ENet_LIBRARIES} sackit ${LUA_LIBRARIES} ${SDL_LIBRARY} ${SDL_LIBRARY})
set_target_properties(iceball-dedi PROPERTIES COMPILE_DEFINITIONS "DEDI")

# iceball-gl target
add_executable(iceball-gl ${MAIN_FILES} ${LUA_FILES} ${GL_FILES})
target_link_libraries(iceball-gl ${PNG_LIBRARIES} ${ENet_LIBRARIES} sackit ${LUA_LIBRARIES} ${SDL_LIBRARY} ${OPENGL_LIBRARIES} ${GLEW_LIBRARIES})
set_target_properties(iceball-gl PROPERTIES COMPILE_DEFINITIONS "USE_OPENGL")

macro(add_dll DLLNAME)
    add_custom_command(TARGET iceball-gl POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_if_different ../winlibs/${DLLNAME} $<TARGET_FILE_DIR:iceball-gl>)
    add_custom_command(TARGET iceball-dedi POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_if_different ../winlibs/${DLLNAME} $<TARGET_FILE_DIR:iceball-dedi>)
endmacro(add_dll)

if (WIN32)
    target_link_libraries(iceball-gl ws2_32 zdll)
    target_link_libraries(iceball-dedi ws2_32 zdll)
    add_dll("lua5.1.dll")
    add_dll("SDL.dll")
    add_dll("glew32.dll")
    add_dll("zlib1.dll")
else()
    #target_link_libraries(iceball zlib)
    #target_link_libraries(iceball-soft zlib)
endif (WIN32)
