cmake_minimum_required(VERSION 3.18)
project(location_hap_native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(FetchContent)
set(BUILD_SHARED_LIBS OFF)
set(BUILD_TESTING OFF)
set(BUILD_TESTS OFF)
set(BUILD_EXAMPLES OFF)
set(ABSL_ENABLE_INSTALL OFF)
set(ABSL_PROPAGATE_CXX_STD ON)

# Pin a Google S2 revision whose library builds without OpenSSL.
FetchContent_Declare(absl
    GIT_REPOSITORY https://github.com/abseil/abseil-cpp.git
    GIT_TAG 5650e9cf76d3be4318d5fa3af38ee483ddfd5e4a
)
FetchContent_Declare(s2geometry
    GIT_REPOSITORY https://github.com/google/s2geometry.git
    GIT_TAG 677c8cebcff11ba11accc0b02005bc214e06e9fd
)
FetchContent_MakeAvailable(absl s2geometry)

add_library(location_grid STATIC s2_grid.cpp)
target_include_directories(location_grid PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(location_grid PRIVATE s2)

if(CMAKE_SYSTEM_NAME STREQUAL "OHOS")
    add_library(location_s2 SHARED s2_bridge.cpp)
    target_link_libraries(location_s2 PRIVATE location_grid libace_napi.z.so)
endif()
