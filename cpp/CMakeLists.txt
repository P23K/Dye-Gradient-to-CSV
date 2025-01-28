cmake_minimum_required(VERSION 3.26)
project(DyeGradienttoCSV)

set(CMAKE_CXX_STANDARD 20)
set(OpenCV_DIR "C:/dev/vcpkg/installed/x64-windows/share/opencv4")

find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

if(WIN32)
    set(APP_ICON_RESOURCE_WINDOWS "${CMAKE_CURRENT_SOURCE_DIR}/resources.rc")
    add_executable(DyeGradienttoCSV main.cpp ${APP_ICON_RESOURCE_WINDOWS})
else()
    add_executable(DyeGradienttoCSV main.cpp)
endif()
target_link_libraries(DyeGradienttoCSV ${OpenCV_LIBS})