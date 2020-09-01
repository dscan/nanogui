# Defaults for e.g., install and build examples change depending on if nanogui
# is the root project or not.
get_directory_property(NANOGUI_MASTER_PROJECT PARENT_DIRECTORY)
if (NANOGUI_MASTER_PROJECT)
  set(NANOGUI_CHILD_DEFAULT OFF)
else()
  set(NANOGUI_CHILD_DEFAULT ON)
endif()

# Configure various option defaults depending on platform, compiler, etc.
if (WIN32)
  set(NANOGUI_BUILD_GLAD_DEFAULT ON)
else()
  set(NANOGUI_BUILD_GLAD_DEFAULT OFF)
endif()

set(NANOGUI_BUILD_SHARED_DEFAULT ON)
set(NANOGUI_BUILD_PYTHON_DEFAULT ON)
set(NANOGUI_BUILD_GLFW_DEFAULT ON)

# Emscripten: static libs required, GLAD / GLFW not needed directly (GLFW builtin).
if (CMAKE_CXX_COMPILER MATCHES "/em\\+\\+(-[a-zA-Z0-9.])?$")
  set(CMAKE_CXX_COMPILER_ID "Emscripten")
  set(NANOGUI_BUILD_SHARED_DEFAULT OFF)
  set(NANOGUI_BUILD_PYTHON_DEFAULT OFF)
  set(NANOGUI_BUILD_GLAD_DEFAULT OFF)
  set(NANOGUI_BUILD_GLFW_DEFAULT OFF)

  set(CMAKE_STATIC_LIBRARY_SUFFIX ".bc")
  set(CMAKE_EXECUTABLE_SUFFIX ".bc")
  set(CMAKE_CXX_CREATE_STATIC_LIBRARY "<CMAKE_CXX_COMPILER> -o <TARGET> <LINK_FLAGS> <OBJECTS>")
  if (U_CMAKE_BUILD_TYPE MATCHES REL)
    add_compile_options(-O3 -DNDEBUG)  # TODO: make this target based.
  endif()
endif()

########################################################################################
# Core options.                                                                        #
########################################################################################
option(BUILD_SHARED_LIBS "Build NanoGUI as a shared library?" ${NANOGUI_BUILD_SHARED_DEFAULT})
option(NANOGUI_BUILD_EXAMPLES "Build NanoGUI example application?" ${NANOGUI_CHILD_DEFAULT})
option(NANOGUI_BUILD_PYTHON "Build a Python plugin for NanoGUI?" ${NANOGUI_BUILD_PYTHON_DEFAULT})
option(NANOGUI_BUILD_GLAD "Build GLAD OpenGL loader library? (needed on Windows)" ${NANOGUI_BUILD_GLAD_DEFAULT})
option(NANOGUI_BUILD_GLFW "Build GLFW?" ${NANOGUI_BUILD_GLFW_DEFAULT})

########################################################################################
# Backend choice.                                                                      #
########################################################################################
set(NANOGUI_AVAILABLE_BACKENDS "OpenGL" "GLES 2" "GLES 3" "Metal")
if (NOT NANOGUI_BACKEND)
  if (CMAKE_SYSTEM_PROCESSOR MATCHES "armv7" OR
      CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64" OR
      CMAKE_CXX_COMPILER MATCHES "/em\\+\\+(-[a-zA-Z0-9.])?$")
    set(NANOGUI_BACKEND_DEFAULT "GLES 2")
  elseif (APPLE)
    set(NANOGUI_BACKEND_DEFAULT "Metal")
  else()
    set(NANOGUI_BACKEND_DEFAULT "OpenGL")
  endif()

  set(NANOGUI_BACKEND ${NANOGUI_BACKEND_DEFAULT} CACHE STRING "Choose the backend used for rendering (OpenGL/GLES 2/GLES 3/Metal)" FORCE)
else()
  if (NOT NANOGUI_BACKEND IN_LIST NANOGUI_AVAILABLE_BACKENDS)
    set(err "NANOGUI_BACKEND=${NANOGUI_BACKEND} invalid")
    foreach (backend ${NANOGUI_AVAILABLE_BACKENDS})
      set(err "${err}, '${backend}'")
    endforeach()
    set(err "${err} are the allowed values.")
    message(FATAL_ERROR "${err}")
  endif()
endif()
set_property(CACHE NANOGUI_BACKEND PROPERTY STRINGS ${NANOGUI_AVAILABLE_BACKENDS})

########################################################################################
# Installation control.                                                                #
########################################################################################
option(NANOGUI_INSTALL "Install NanoGUI on `make install`?" ${NANOGUI_CHILD_DEFAULT})
option(NANOGUI_INSTALL_RPATH "Use full RPATH handling when installing?" ON)

if (NANOGUI_INSTALL)
  # The majority of the install logic takes place at the end, but these
  # variables are needed now for cmake/nanogui/external_dependencies.cmake.
  include(GNUInstallDirs)

  # Where to install third party header files, e.g., nanovg.h.
  set(NANOGUI_INSTALL_INCLUDEDIR_EXTERNAL "${CMAKE_INSTALL_INCLUDEDIR}/nanogui/external")

  # Let users define where to install nanogui-config.cmake and friends.  If not
  # defined at configure time, use lib/cmake.  Unfortunately, there is no standardized
  # CMAKE_INSTALL_* variable for this.  Typical choice is lib/cmake.
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

########################################################################################
# Advanced options.                                                                    #
########################################################################################
# TODO
option(NANOGUI_STBI_IMPLEMENTATION "Bundle stb_image definitions in NanoGUI (STB_IMAGE_IMPLEMENTATION)?" ON)
mark_as_advanced(NANOGUI_STBI_IMPLEMENTATION)
option(NANOGUI_USE_LIBCXX "With Clang, link against libc++ / libc++abi?" ON)
mark_as_advanced(NANOGUI_USE_LIBCXX)
# end todo
# See top of cmake/developer.cmake.  This is *not* for parent projects / install.
option(NANOGUI_DEV "Add NanoGUI dev flags (warnings on, warnings=error) and targets?" OFF)
mark_as_advanced(NANOGUI_DEV)

# TODO: revisit this?
# Third party dependency control bypasses.  These are neither options nor cache
# entries, but allow two kinds of interactions.  The "options" are:
#
# - NANOGUI_EXTERNAL_GLAD
# - NANOGUI_EXTERNAL_EIGEN
# - NANOGUI_EXTERNAL_GLFW
#
# You may either set them to ON trigger a find_package call, or set them to
# an already-defined target to force NanoGUI to link against.  See
# cmake/nanogui/external_dependencies.cmake for usage.

# I think we should just find_package() and if it is not found, add NANOGUI_EXTERNAL_X_REQUIRED
# variable.  If that is ON then we fail hard, but otherwise fallback on our vendored versions.
