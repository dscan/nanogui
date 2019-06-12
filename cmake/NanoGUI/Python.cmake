# Try to autodetect Python (can be overridden manually if needed by configuring
# with `-DNANOGUI_PYTHON_VERSION=x.y`.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/ext/pybind11/tools")
set(Python_ADDITIONAL_VERSIONS 3.8 3.7 3.6 3.5 3.4)
find_package(PythonLibsNew ${NANOGUI_PYTHON_VERSION})
if (NOT PYTHONLIBS_FOUND)
  # Python not found -- disable the plugin
  set(NANOGUI_BUILD_PYTHON OFF CACHE BOOL "Build a Python plugin for NanoGUI?" FORCE)
  message(WARNING "NanoGUI: not building the Python plugin!")
else()
  message(STATUS "NanoGUI: building the Python plugin.")
endif()

# DANGER: don't `return()` if not found...this file is `include()`ed.
if (NANOGUI_BUILD_PYTHON)
  # Core python library setup.
  target_compile_definitions(nanogui-python-obj PRIVATE NANOGUI_PYTHON)
  target_include_directories(nanogui-python-obj
    PRIVATE
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/pybind11/include
      ${PYTHON_INCLUDE_DIR}
  )
  target_link_libraries(nanogui-python PUBLIC nanogui)
  set_target_properties(nanogui-python
    PROPERTIES
      # NOTE: see *_OUTPUT_DIRECTORY target properties below.  Must not generate
      # to same output directory as main nanogui library, otherwise cmake may
      # create invalid Ninja build files duplicating `nanogui` target.
      OUTPUT_NAME nanogui
      # Prefix / extension provided by FindPythonLibsNew.cmake.
      PREFIX "${PYTHON_MODULE_PREFIX}"
      SUFFIX "${PYTHON_MODULE_EXTENSION}"
  )

  # Need PIC code in libnanogui even when compiled as a static library.
  set_target_properties(nanogui nanogui-obj nanogui-python nanogui-python-obj
    PROPERTIES
      POSITION_INDEPENDENT_CODE ON
  )
  if (TARGET glfw_objects)
    set_target_properties(glfw_objects
      PROPERTIES
        POSITION_INDEPENDENT_CODE ON
    )
  endif()

  # Set where nanogui-python library gets put in build tree.
  if (CMAKE_CONFIGURATION_TYPES)  # Multi-config generators
    set_target_properties(nanogui-python
      PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY_DEBUG "Debug/python"
        LIBRARY_OUTPUT_DIRECTORY_DEBUG "Debug/python"
        RUNTIME_OUTPUT_DIRECTORY_DEBUG "Debug/python"
        ARCHIVE_OUTPUT_DIRECTORY_RELEASE "Release/python"
        LIBRARY_OUTPUT_DIRECTORY_RELEASE "Release/python"
        RUNTIME_OUTPUT_DIRECTORY_RELEASE "Release/python"
        ARCHIVE_OUTPUT_DIRECTORY_MINSIZEREL "MinSizeRel/python"
        LIBRARY_OUTPUT_DIRECTORY_MINSIZEREL "MinSizeRel/python"
        RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "MinSizeRel/python"
        LIBRARY_OUTPUT_DIRECTORY_RELWITHDEBINFO "RelWithDebInfo/python"
        ARCHIVE_OUTPUT_DIRECTORY_RELWITHDEBINFO "RelWithDebInfo/python"
        RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "RelWithDebInfo/python"
    )
  else()
    # NOTE: need to set all three for using Ninja with cl.exe on Windows.
    set_target_properties(nanogui-python
      PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/python
        LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/python
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/python
    )
  endif()

  # Platform specific treatment.
  if (WIN32)
    # Link against the Python shared library
    target_link_libraries(nanogui-python PUBLIC ${PYTHON_LIBRARY})

    if (MSVC)
      # Optimize for size, /bigobj is needed for due to the heavy template
      # metaprogramming in pybind11.
      target_compile_options(nanogui-python-obj
        PRIVATE
          /bigobj
          $<$<CONFIG:Release>:/Os>
          $<$<CONFIG:MinSizeRel>:/Os>
          $<$<CONFIG:RelWithDebInfo>:/Os>
      )
    endif()
  elseif (UNIX)
    # Optimize python library for size.
    if (U_CMAKE_BUILD_TYPE MATCHES REL)
      target_compile_options(nanogui-python-obj PRIVATE -Os)
    endif()

    if (APPLE)
      set_target_properties(nanogui-python
        PROPERTIES
          LINK_FLAGS "-undefined dynamic_lookup"
      )
    endif()
  endif()

  check_cxx_compiler_flag(-Wno-unused-variable have_no_unused_variable)
  if (have_no_unused_variable)
    target_compile_options(nanogui-python-obj PRIVATE -Wno-unused-variable)
  endif()
endif()
