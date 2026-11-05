cmake_minimum_required(VERSION 3.16)
project(xdl_consumer C)

find_package(SDL3 REQUIRED CONFIG)

add_executable(consumer main.c)
target_link_libraries(consumer PRIVATE SDL3::SDL3)
