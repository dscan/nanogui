cmake_minimum_required(VERSION 3.13 FATAL_ERROR)
project(nanogui-test-package LANGUAGES CXX)

if (NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 11)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Re-use example1 since it uses almost all features of NanoGUI.
add_executable(example1 ${CMAKE_CURRENT_SOURCE_DIR}/../src/example1.cpp)
# Copy icons for example1 application.
file(
  COPY ${CMAKE_CURRENT_SOURCE_DIR}/../resources/icons
  DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
)

find_package(nanogui 0.1.0 CONFIG REQUIRED)
target_link_libraries(example1 PRIVATE nanogui::nanogui)

message(STATUS "Found NanoGUI ${nanogui_VERSION} HEAD=${nanogui_REVISION}")
