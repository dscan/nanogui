# When NanoGUI installs, some headers will be bundled.  For example, NanoVG will
# always be bundled on install.  Additionally, if dependencies such as Eigen are
# not found externally, they will be bundled as well.
if (NANOGUI_INSTALL)
  target_include_directories(nanogui-interface
    INTERFACE
      $<INSTALL_INTERFACE:${NANOGUI_INSTALL_INCLUDEDIR_EXTERNAL}>
  )
endif()

################################################################################
# Coro (coroutine support for detaching mainloop).                             #
################################################################################
if (NANOGUI_BUILD_PYTHON)
  if (APPLE OR CMAKE_SYSTEM MATCHES Linux)
    # NOTE: Coro headers do not need to be installed, they are only needed for
    # building Python.
    target_compile_definitions(nanogui-python-obj PRIVATE CORO_SJLJ)
    target_include_directories(nanogui-python-obj
      PRIVATE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/ext/coro>
    )
    target_sources(nanogui-python-obj PRIVATE
      ext/coro/coro.h
      ext/coro/coro.c
    )

    # Silence warnings about `trampoline (int sig)` in coro.c:108.
    check_cxx_compiler_flag(-Wno-unused-parameter have_no_unused_parameter)
    if (have_no_unused_parameter)
      set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/ext/coro/coro.c
        PROPERTIES
          COMPILE_FLAGS -Wno-unused-parameter
      )
    endif()
  endif()
endif()

################################################################################
# Eigen vector math library.                                                   #
################################################################################
if (DEFINED NANOGUI_EIGEN_INCLUDE_DIR)
  message(FATAL_ERROR "NANOGUI_EIGEN_INCLUDE_DIR is no longer supported. "
    "Please set NANOGUI_EXTERNAL_EIGEN instead.")
endif()
set(NANOGUI_VENDOR_EIGEN TRUE) # used in nanogui-config.cmake.
if (DEFINED NANOGUI_EXTERNAL_EIGEN)
  if (TARGET ${NANOGUI_EXTERNAL_EIGEN})
    target_link_libraries(nanogui-interface INTERFACE ${NANOGUI_EXTERNAL_EIGEN})
  else()
    find_package(Eigen3 CONFIG)
    if (NOT TARGET Eigen3::Eigen)
      message(FATAL_ERROR "NANOGUI_EXTERNAL_EIGEN was defined, but could not "
        "find_package(Eigen3 CONFIG).")
    endif()
    message(STATUS "Found Eigen3: ${Eigen3_DIR}")
    target_link_libraries(nanogui-interface INTERFACE Eigen3::Eigen)
    set(NANOGUI_VENDOR_EIGEN FALSE)
  endif()
else()
  target_include_directories(nanogui-interface
    INTERFACE
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/ext/eigen>
  )
  if (NANOGUI_INSTALL)
    install(
      DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ext/eigen/Eigen
      DESTINATION ${NANOGUI_INSTALL_INCLUDEDIR_EXTERNAL}
    )
  endif()
endif()

# Avoid unaligned access segfaults on 32 bit builds with Eigen.
if (NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  # Previously: EIGEN_DONT_ALIGN
  target_compile_definitions(nanogui-interface INTERFACE EIGEN_MAX_ALIGN_BYTES=0)

  if (MSVC)
    target_compile_options(nanogui-private-interface INTERFACE /arch:SSE2)
  endif()
endif()

################################################################################
# GLAD graphics language loader.                                               #
################################################################################
set(NANOGUI_VENDOR_GLAD TRUE) # used in nanogui-config.cmake
if (NANOGUI_USE_GLAD)
  # Triggers nanogui/opengl.h to #include glad headers.
  target_compile_definitions(nanogui-interface INTERFACE NANOGUI_GLAD)

  if (DEFINED NANOGUI_EXTERNAL_GLAD)
    if (TARGET ${NANOGUI_EXTERNAL_GLAD})
      target_link_libraries(nanogui-interface INTERFACE ${NANOGUI_EXTERNAL_GLAD})
    else()
      find_package(glad CONFIG)
      if (NOT TARGET glad::glad)
        message(FATAL_ERROR "NANOGUI_EXTERNAL_GLAD was defined, but could not "
          "find_package(glad CONFIG).")
      endif()
      message(STATUS "Found glad: ${glad_DIR}")
      target_link_libraries(nanogui-interface INTERFACE glad::glad)
      set(NANOGUI_VENDOR_GLAD FALSE)
    endif()
  else()
    # GLAD is bundled into NanoGUI unconditionally.
    target_sources(nanogui-obj PRIVATE
      ext/glad/src/glad.c
      ext/glad/include/glad/glad.h
      ext/glad/include/KHR/khrplatform.h
    )

    # C4055 removed in MSVC 2017 and later
    if (MSVC AND MSVC_VERSION VERSION_LESS 1900)
      set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/ext/glad/src/glad.c
        PROPERTIES COMPILE_FLAGS "/wd4055 ")
    endif()

    target_include_directories(nanogui-interface
      INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/ext/glad/include>
    )

    if (BUILD_SHARED_LIBS)
      # When importing GLAD_GLAPI_EXPORT should be defined.  When compiling,
      # GLAD_GLAPI_EXPORT_BUILD should be defined (for exporting).
      target_compile_definitions(nanogui-interface INTERFACE GLAD_GLAPI_EXPORT)
      target_compile_definitions(nanogui-obj PRIVATE GLAD_GLAPI_EXPORT_BUILD)
    endif()

    # Bundle the GLAD headers in the installation.
    if (NANOGUI_INSTALL)
      foreach (glad_dir glad KHR)
        install(
          DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ext/glad/include/${glad_dir}
          DESTINATION ${NANOGUI_INSTALL_INCLUDEDIR_EXTERNAL}
        )
      endforeach()
    endif()
  endif()
endif()

################################################################################
# GLFW Graphics Library Framework.                                             #
################################################################################
set(NANOGUI_VENDOR_GLFW TRUE) # used in nanogui-config.cmake
if (DEFINED NANOGUI_EXTERNAL_GLFW)
  if (TARGET ${NANOGUI_EXTERNAL_GLFW})
    target_link_libraries(nanogui-interface INTERFACE ${NANOGUI_EXTERNAL_GLFW})
  else()
    find_package(glfw3 CONFIG)
    if (NOT TARGET glfw)
      message(FATAL_ERROR "NANOGUI_EXTERNAL_GLFW was defined, but could not "
        "find_package(glfw3 CONFIG).")
    endif()
    message(STATUS "Found glfw3: ${glfw3_DIR}")
    target_link_libraries(nanogui-interface INTERFACE glfw)
    set(NANOGUI_VENDOR_GLFW FALSE)
  endif()
else()
  # Compile GLFW
  # TODO: re-verify these
  set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL " " FORCE)
  set(GLFW_BUILD_TESTS OFF CACHE BOOL " " FORCE)
  set(GLFW_BUILD_DOCS OFF CACHE BOOL " " FORCE)
  set(GLFW_BUILD_INSTALL OFF CACHE BOOL " " FORCE)
  set(GLFW_INSTALL OFF CACHE BOOL " " FORCE)
  set(GLFW_USE_CHDIR OFF CACHE BOOL " " FORCE)

  # TODO: shouldn't be necessary anymore since we exclude
  # set(BUILD_SHARED_LIBS ${NANOGUI_BUILD_SHARED} CACHE BOOL " " FORCE)

  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # Quench annoying deprecation warnings when compiling GLFW on OSX
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-deprecated-declarations")
  endif()

  # We exclude from all and then consume $<TARGET_OBJECTS> meaning the main glfw
  # library will not actually be built.
  add_subdirectory(ext/glfw ext_build/glfw EXCLUDE_FROM_ALL)
  target_sources(nanogui PRIVATE $<TARGET_OBJECTS:glfw_objects>)

  target_include_directories(nanogui-interface
    INTERFACE
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/ext/glfw/include>
  )

  if (BUILD_SHARED_LIBS)
    # When GLFW is merged into the NanoGUI library, this flag must be specified
    target_compile_definitions(nanogui-obj PRIVATE _GLFW_BUILD_DLL)
    set_target_properties(glfw_objects PROPERTIES POSITION_INDEPENDENT_CODE ON)
  endif()

  # Bundle GLFW headers in NanoGUI installation.
  if (NANOGUI_INSTALL)
    install(
      DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ext/glfw/include/GLFW
      DESTINATION ${NANOGUI_INSTALL_INCLUDEDIR_EXTERNAL}
    )
  endif()
endif()

################################################################################
# NanoVG Antialiased 2D vector drawing library.                                #
################################################################################
# Merge NanoVG into the NanoGUI library.
target_sources(nanogui-obj PRIVATE
  ext/nanovg/src/fontstash.h
  ext/nanovg/src/nanovg.h
  ext/nanovg/src/nanovg_gl.h
  ext/nanovg/src/nanovg_gl_utils.h
  ext/nanovg/src/stb_image.h
  ext/nanovg/src/stb_truetype.h
  ext/nanovg/src/nanovg.c
)
target_include_directories(nanogui-interface
  INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/ext/nanovg/src>
)

# dllimport/dllexport macro, see nanovg.h
target_compile_definitions(nanogui-obj PRIVATE NVG_BUILD)

# Let parents prevent stb_image definitions ending up in NanoGUI (set to OFF).
if (NANOGUI_STBI_IMPLEMENTATION)
  target_compile_definitions(nanogui-obj PRIVATE NVG_STB_IMAGE_IMPLEMENTATION)
  # See modifications near #define STBIDEF in ext/nanovg/src/stb_image.h.
  target_compile_definitions(nanogui-interface INTERFACE STBI_EXPORTS)
endif()
if (BUILD_SHARED_LIBS)
  target_compile_definitions(nanogui-interface INTERFACE NVG_SHARED)
  if (NANOGUI_STBI_IMPLEMENTATION)
    target_compile_definitions(nanogui-interface INTERFACE STBI_SHARED)
  endif()
endif()

# Quench warnings while compiling NanoVG
set(nanovg_compiler_bypasses)
if (MSVC)
  set(nanovg_compiler_bypasses "/wd4005;/wd4456;/wd4457")
else()
  check_cxx_compiler_flag(-Wno-misleading-indentation have_no_misleading_indentation)
  if (have_no_misleading_indentation)
    list(APPEND nanovg_compiler_bypasses -Wno-misleading-indentation)
  endif()

  check_cxx_compiler_flag(-Wno-shift-negative-value have_no_shift_negative_value)
  if (have_no_shift_negative_value)
    list(APPEND nanovg_compiler_bypasses -Wno-shift-negative-value)
  endif()

  check_cxx_compiler_flag(-Wno-sign-compare have_no_sign_compare)
  if (have_no_sign_compare)
    list(APPEND nanovg_compiler_bypasses -Wno-sign-compare)
  endif()

  check_cxx_compiler_flag(-Wno-implicit-fallthrough have_no_implicit_fallthrough)
  if (have_no_implicit_fallthrough)
    list(APPEND nanovg_compiler_bypasses -Wno-implicit-fallthrough)
  endif()
endif()

if (nanovg_compiler_bypasses)
  set_property(
    SOURCE
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/nanovg/src/nanovg.c
    APPEND
    PROPERTY
      COMPILE_OPTIONS ${nanovg_compiler_bypasses}
  )
endif()

# Install the NanoVG headers.
if (NANOGUI_INSTALL)
  install(
    FILES
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/nanovg/src/fontstash.h
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/nanovg/src/nanovg.h
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/nanovg/src/nanovg_gl.h
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/nanovg/src/nanovg_gl_utils.h
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/nanovg/src/stb_image.h
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/nanovg/src/stb_truetype.h
    DESTINATION
      ${NANOGUI_INSTALL_INCLUDEDIR_EXTERNAL}
  )
endif()

################################################################################
# Required core libraries on various platforms.                                #
################################################################################
# NOTE: See https://cmake.org/cmake/help/latest/module/FindThreads.html
# It is claimed that with C++11 and later this is not needed, but in practice
# this is not true (typically link errors on consuming targets of nanogui).
find_package(Threads)
if (TARGET Threads::Threads)
  target_link_libraries(nanogui-private-interface INTERFACE Threads::Threads)
endif()

set(nanogui_core_libs)
if (WIN32)
  set(nanogui_core_libs opengl32)
elseif (APPLE)
  set(nanogui_core_libs Cocoa OpenGL CoreVideo IOKit)
  target_sources(nanogui-obj PRIVATE src/darwin.mm)
elseif (CMAKE_SYSTEM MATCHES "Linux" OR CMAKE_SYSTEM_NAME MATCHES "BSD")
  set(nanogui_core_libs GL Xxf86vm Xrandr Xinerama Xcursor Xi X11)
endif()

foreach (lib ${nanogui_core_libs})
  find_library(${lib}_library ${lib})
  if (NOT ${lib}_library)
    message(SEND_ERROR "System ${lib} library not found!")
  endif()
  target_link_libraries(nanogui-interface INTERFACE ${${lib}_library})
endforeach()
