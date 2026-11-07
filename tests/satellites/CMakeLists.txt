cmake_minimum_required(VERSION 3.16)
project(xdl_satellites C)

find_package(SDL3 REQUIRED CONFIG)
find_package(SDL3_image REQUIRED CONFIG)
find_package(SDL3_ttf REQUIRED CONFIG)
find_package(SDL3_mixer REQUIRED CONFIG)

add_executable(consumer consumer.c)
target_link_libraries(consumer PRIVATE SDL3_image::SDL3_image SDL3_ttf::SDL3_ttf SDL3_mixer::SDL3_mixer SDL3::SDL3)

# Links no SDL library: it loads the published files at run time.
add_executable(runtime-layout runtime-layout.c)
target_link_libraries(runtime-layout PRIVATE SDL3::Headers ${CMAKE_DL_LIBS})

# RUNTIME_DIR holds the published files. XDL_REVISION is the SDL_REVISION that XDL3 was built with, which SDL_GetRevision() starts with.
enable_testing()
if(RUNTIME_DIR AND XDL_REVISION)
  add_test(NAME runtime-layout COMMAND runtime-layout "${RUNTIME_DIR}" "${XDL_REVISION}")
  set_tests_properties(runtime-layout PROPERTIES ENVIRONMENT SDL_VIDEODRIVER=dummy)
endif()
