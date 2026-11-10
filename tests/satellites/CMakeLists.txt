cmake_minimum_required(VERSION 3.16)
project(xdl_satellites C)

find_package(SDL3 REQUIRED CONFIG)
find_package(SDL3_image REQUIRED CONFIG)
find_package(SDL3_ttf REQUIRED CONFIG)
find_package(SDL3_mixer REQUIRED CONFIG)

add_executable(consumer consumer.c)
target_link_libraries(consumer PRIVATE SDL3_image::SDL3_image SDL3_ttf::SDL3_ttf SDL3_mixer::SDL3_mixer SDL3::SDL3)

add_executable(ttf-typography ttf-typography.c)
target_link_libraries(ttf-typography PRIVATE SDL3_ttf::SDL3_ttf SDL3::SDL3)

# Links no SDL library: it loads the published files at run time.
add_executable(runtime-layout runtime-layout.c)
target_link_libraries(runtime-layout PRIVATE SDL3::Headers ${CMAKE_DL_LIBS})

# RUNTIME_DIR holds the published files. XDL_REVISION is the SDL_REVISION that XDL3 was built with, which SDL_GetRevision() starts with.
# One test per library loaded first, each in a process of its own, so no earlier load finds XDL3 for a satellite.
enable_testing()
if(RUNTIME_DIR AND XDL_REVISION)
  foreach(first XDL3 XDL3_image XDL3_ttf XDL3_mixer)
    add_test(NAME runtime-layout-${first} COMMAND runtime-layout "${RUNTIME_DIR}" "${XDL_REVISION}" ${first})
    set_tests_properties(runtime-layout-${first} PROPERTIES ENVIRONMENT SDL_VIDEODRIVER=dummy)
  endforeach()
endif()

add_test(NAME ttf-typography COMMAND ttf-typography "${CMAKE_CURRENT_SOURCE_DIR}/fonts/Cantarell-VF.otf")
# Windows has no RPATH, so the test finds the DLLs in RUNTIME_DIR.
if(WIN32 AND RUNTIME_DIR)
  set_tests_properties(ttf-typography PROPERTIES ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:${RUNTIME_DIR}")
endif()
