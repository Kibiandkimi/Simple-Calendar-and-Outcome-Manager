# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.28)

project(database_library)

set(CMAKE_CXX_STANDARD 20)

set(CMAKE_CXX_SCAN_FOR_MODULES 0)

add_compile_definitions(SQLITE_ENABLE_RTREE
    SQLITE_ENABLE_COLUMN_METADATA
    SQLITE_ENABLE_DESERIALIZE
    SQLITE_ENABLE_FTS5
    SQLITE_ENABLE_FTS3)

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    message(STATUS "Building for Android platform!")
    add_compile_definitions(__ANDROID__)
endif ()

if(ANDROID)
    message(STATUS "Building for Android platform.")
    add_compile_definitions(__ANDROID__)
endif ()

add_library(database SHARED
  "database.cpp"
)

set_target_properties(database PROPERTIES
  PUBLIC_HEADER database.h
  OUTPUT_NAME "database"
)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(sqlite3 STATIC sqlite3.c)

add_library(easylogging STATIC easylogging++.cc)

target_link_libraries(database PRIVATE sqlite3)
target_link_libraries(database PRIVATE easylogging)

target_compile_definitions(database PUBLIC DART_SHARED_LIB)

if (TEST)
    add_compile_definitions(TEST)
    add_executable(SCOM_database_TEST test/test.cpp)
    target_link_libraries(SCOM_database_TEST PRIVATE database)
    target_include_directories(SCOM_database_TEST PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
endif ()
