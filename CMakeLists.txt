cmake_minimum_required(VERSION 3.13.3 FATAL_ERROR)

# CMake 3.15 introduces MSVC_RUNTIME_LIBRARY target property.
# Must be done before `project` call.  See:
# https://cmake.org/cmake/help/latest/prop_tgt/MSVC_RUNTIME_LIBRARY.html
#
# Prior to 3.15, /MD[d] added for MSVC *unless* /MT[d] found in CMAKE_CXX_FLAGS.
if (POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()

project("NanoGUI" VERSION 0.1.0 LANGUAGES C CXX)

################################################################################
# NanoGUI options.                                                             #
################################################################################
# Off by default when NanoGUI is a child project: examples, install
get_directory_property(NANOGUI_HAS_PARENT PARENT_DIRECTORY)
if (NANOGUI_HAS_PARENT)
  set(NANOGUI_CHILD_DEFAULT OFF)
else()
  set(NANOGUI_CHILD_DEFAULT ON)
endif()

# Use glad by default if Windows _or_ NANOGUI_EXTERNAL_GLAD requested.
if (WIN32 OR DEFINED NANOGUI_EXTERNAL_GLAD)
  set(NANOGUI_USE_GLAD_DEFAULT ON)
else()
  set(NANOGUI_USE_GLAD_DEFAULT OFF)
endif()

option(BUILD_SHARED_LIBS "Build NanoGUI as a shared library?" ON)
option(NANOGUI_BUILD_EXAMPLE "Build NanoGUI example application?" ${NANOGUI_CHILD_DEFAULT})
option(NANOGUI_BUILD_PYTHON "Build a Python plugin for NanoGUI?" ON)
option(NANOGUI_USE_GLAD "Use Glad OpenGL loader library?" ${NANOGUI_USE_GLAD_DEFAULT})
option(NANOGUI_STBI_IMPLEMENTATION "Bundle stb_image definitions in NanoGUI (STB_IMAGE_IMPLEMENTATION)?" ON)
option(NANOGUI_USE_LIBCXX "With Clang, link against libc++ / libc++abi?" ON)
option(NANOGUI_INSTALL "Install NanoGUI on `make install`?" ${NANOGUI_CHILD_DEFAULT})
option(NANOGUI_INSTALL_RPATH "Use full RPATH handling when installing?" ON)
option(NANOGUI_DEV "Add NanoGUI dev flags (warnings on, warnings=error) and targets?" OFF)
mark_as_advanced(NANOGUI_DEV)

set(NANOGUI_PYTHON_VERSION "" CACHE STRING "Python version to use for compiling the Python plugin")

# Third party dependency control bypasses.  These are neither options nor cache
# entries, but allow two kinds of interactions.  The "options" are:
#
# - NANOGUI_EXTERNAL_GLAD
# - NANOGUI_EXTERNAL_EIGEN
# - NANOGUI_EXTERNAL_GLFW
#
# You may either set define them to trigger a find_package call, or set them to
# an already-defined target to force NanoGUI to link against.  See
# cmake/NanoGUI/ExternalDependencies.cmake for usage.

# NanoGUI adheres to the defaults defined by GNUInstallDirs, which are  the
# defaults in CMake 3.14+.  See `TYPE` argument:
# https://cmake.org/cmake/help/latest/command/install.html#installing-files
#
# If a consumer seeks to change the install behavior of NanoGUI, they should set
# the corresponding GNUInstallDirs variable.  For example, if configured with
# `-DNANOGUI_INSTALL=ON -DCMAKE_INSTALL_LIBDIR=lib` then the libraries will be
# installed to ${CMAKE_INSTALL_PREFIX}/lib (whereas the default may have been
# `lib64` on many linux systems).  NanoGUI utilizes the following variables:
#
# CMAKE_INSTALL_BINDIR (typically: `bin`)
#     Only used if Windows // shared libraries (DLLs install here).
#
# CMAKE_INSTALL_LIBDIR (typically: `lib` or `lib64`)
#     Libraries install here.  NanoGUI will also install CMake packaging
#     utilities to ${CMAKE_INSTALL_LIBDIR}/cmake/nanogui _unless_
#     NANOGUI_INSTALL_CONFIGDIR is defined (see below).
#
# CMAKE_INSTALL_INCLUDEDIR (typically: `include`)
#     Header files install here.  NanoGUI will also install any third party
#     headers to ${CMAKE_INSTALL_INCLUDE_DIR}/nanogui/external.
#
# CMAKE_INSTALL_DATADIR (typicall: `share`)
#     The NanoGUI license as well as licenses from any third party projects that
#     are vendored in the installation are installed to
#     ${CMAKE_INSTALL_DATADIR}/nanogui.
if (NANOGUI_INSTALL)
  # The majority of the install logic takes place at the end, but these
  # variables are needed now for cmake/NanoGUI/ExternalDependencies.cmake.
  include(GNUInstallDirs)
  set(NANOGUI_INSTALL_INCLUDEDIR_EXTERNAL "${CMAKE_INSTALL_INCLUDEDIR}/nanogui/external")

  # Let users define where to install nanogui-config.cmake and friends.  If not
  # defined at configure time, use lib/cmake.
  if (NOT DEFINED NANOGUI_INSTALL_CONFIGDIR)
    set(NANOGUI_INSTALL_CONFIGDIR "${CMAKE_INSTALL_LIBDIR}/cmake")
  endif()

  # By default we do "Always full RPATH".  Now that we have the install
  # destinations available, setup RPATH *before* any targets are created.
  # See: https://gitlab.kitware.com/cmake/community/wikis/doc/cmake/RPATH-handling
  if (NANOGUI_INSTALL_RPATH)
    set(CMAKE_SKIP_BUILD_RPATH FALSE)
    set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
    set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
    set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
  endif()
endif()

################################################################################
# Initial project setup.                                                       #
################################################################################
# Setup -std=c++11 for all compilers if CMAKE_CXX_STANDARD not yet defined.
# Users can configure with e.g., -DCMAKE_CXX_STANDARD=14 for C++14.
if (CMAKE_CXX_STANDARD)
  if (CMAKE_CXX_STANDARD VERSION_LESS 11)
    message(FATAL_ERROR "NanoGUI requires C++11 or later, but "
      "CMAKE_CXX_STANDARD=${CMAKE_CXX_STANDARD}")
  endif()
else()
  set(CMAKE_CXX_STANDARD 11)
endif()
# The specified CMAKE_CXX_STANDARD is required for compilation.
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# Unless parent project specifies to allow extensions, prefer official standards
# e.g., prefer -std=c++11 over -std=gnu++11.
if (NOT DEFINED CMAKE_CXX_EXTENSIONS)
  set(CMAKE_CXX_EXTENSIONS OFF)
endif()

# Make sure the submodules have been downloaded.
if (NOT IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/ext/glfw/src")
  message(FATAL_ERROR "The NanoGUI dependency repositories (GLFW, etc.) are missing! "
    "You probably did not clone the project with --recursive. It is possible to recover "
    "by calling \"git submodule update --init --recursive\"")
endif()

# If unspecified, default to Release.  Doesn't apply to multi-config generators.
if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release"
    "MinSizeRel" "RelWithDebInfo")
endif()
string(TOUPPER "${CMAKE_BUILD_TYPE}" U_CMAKE_BUILD_TYPE)

# Make the NanoGUI custom cmake files available.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Used to test compiler / linker flags for e.g., -flto or libc++ support.
include(CheckCXXCompilerFlag)
include(CheckCXXSourceRuns)
set(CMAKE_REQUIRED_QUIET TRUE)
macro(check_cxx_compiler_and_linker_flags result cxx_flags linker_flags)
  set(CMAKE_REQUIRED_FLAGS ${cxx_flags})
  set(CMAKE_REQUIRED_LIBRARIES ${linker_flags})
  check_cxx_source_runs("int main(int argc, char **argv) { return 0; }" ${result})
  set(CMAKE_REQUIRED_FLAGS "")
  set(CMAKE_REQUIRED_LIBRARIES "")
endmacro()

################################################################################
# Main target setup.                                                           #
################################################################################
# The main targets that will be built.
add_library(nanogui-interface INTERFACE)
add_library(nanogui-private-interface INTERFACE)  # Only used internally.
add_library(nanogui "")
add_library(nanogui-obj OBJECT "")
if (NANOGUI_BUILD_PYTHON)
  add_library(nanogui-python "")
  add_library(nanogui-python-obj OBJECT "")
endif()

# Create alias targets for parent projects to link against e.g. nanogui::nanogui
foreach (tgt nanogui-interface nanogui nanogui-obj nanogui-python nanogui-python-obj)
  if (TARGET ${tgt})
    add_library(nanogui::${tgt} ALIAS ${tgt})
  endif()
endforeach()

# Set platform independent target_sources nanogui-obj and nanogui-python-obj.
include(NanoGUI/PrimaryTargetSources)

# Create dependencies between the various targets (e.g., link nanogui with interface).
include(NanoGUI/InternalDependencies)

# Find or compile the dependencies required for NanoGUI.  Also responsible for
# setting up include directories, linking against libraries, etc.
include(NanoGUI/ExternalDependencies)

# Setup project / platform specific compilation flags / definitions.
include(NanoGUI/CompileOptions)

# Add high warning levels and add custom targets for generating python docs.
# NOTE: include before ExternalDependencies so that sub-projects get warnings.
if (NANOGUI_DEV)
  include(NanoGUI/Developer)
endif()

# Setup python bindings (include after NanoGUI/CompileOptions).
if (NANOGUI_BUILD_PYTHON)
  include(NanoGUI/Python)
endif()

# Setup primary installation logic (include after NanoGUI/Python).
if (NANOGUI_INSTALL)
  include(NanoGUI/Install)
endif()

################################################################################
# Strip unnecessary sections of the binary on Linux/Mac OS.                    #
################################################################################
if (UNIX AND NOT U_CMAKE_BUILD_TYPE MATCHES DEB)
  set(strip_flags)
  if (BUILD_SHARED_LIBS)
    # TODO: why do we strip shared here but shared|static for python?  Why not
    # strip both for C++ library?
    add_custom_command(
      TARGET nanogui
      COMMAND
        ${CMAKE_STRIP} "$<$<PLATFORM_ID:Darwin>:-u;-r>" $<TARGET_FILE:nanogui>
      COMMAND_EXPAND_LISTS
      POST_BUILD
      COMMENT
        "Stripping nanogui library."
    )
  endif()
  if (TARGET nanogui-python)
    add_custom_command(
      TARGET nanogui-python
      COMMAND
        ${CMAKE_STRIP} "$<$<PLATFORM_ID:Darwin>:-u;-r>" $<TARGET_FILE:nanogui-python>
      COMMAND_EXPAND_LISTS
      POST_BUILD
      COMMENT
        "Stripping nanogui-python library."
    )
  endif()
endif()

################################################################################
# Build example applications if requested.                                     #
################################################################################
if (NANOGUI_BUILD_EXAMPLE)
  add_executable(example1      src/example1.cpp)
  add_executable(example2      src/example2.cpp)
  add_executable(example3      src/example3.cpp)
  add_executable(example4      src/example4.cpp)
  add_executable(example_icons src/example_icons.cpp)
  foreach (ex example1 example2 example3 example4 example_icons)
    target_link_libraries(${ex} PRIVATE nanogui)
  endforeach()

  # Copy icons for example1 application.
  file(COPY resources/icons DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
endif()
# vim: set et ts=2 sw=2 ft=cmake nospell:
