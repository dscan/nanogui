# This file manipulates compilation flags dependent upon platform / options.
# The core include directory.
target_include_directories(nanogui-interface
  INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Configures dllimport/dllexport definitions (see common.h).
target_compile_definitions(nanogui-obj PRIVATE NANOGUI_BUILD)

# Switch designed to fall-through, attribute available in C++17.
check_cxx_compiler_flag(-Wno-implicit-fallthrough have_no_implicit_fallthrough)
if (have_no_implicit_fallthrough)
  set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/src/common.cpp
    PROPERTIES
      COMPILE_OPTIONS -Wno-implicit-fallthrough
  )
endif()

################################################################################
# Various configurations for shared library builds.                            #
################################################################################
if (BUILD_SHARED_LIBS)
  # Configures dllimport/dllexport flags for all symbols (see common.h).
  target_compile_definitions(nanogui-interface INTERFACE NANOGUI_SHARED)

  # Build PIC code for shared libraries.
  set_property(TARGET nanogui-obj PROPERTY POSITION_INDEPENDENT_CODE ON)

  # NanoGUI exports its symbols, mark the default visibility as hidden.
  foreach (tgt nanogui nanogui-obj nanogui-python nanogui-python-obj)
    if (TARGET ${tgt})
      set_target_properties(${tgt}
        PROPERTIES
          CXX_VISIBILITY_PRESET "hidden"
          VISIBILITY_INLINES_HIDDEN ON
      )
    endif()
  endforeach()

  # Add IPO (link time optimization) compile / link flags for Release,
  # MinSizeRel, and RelWithDebInfo builds.
  # NOTE: CheckIPOSupported added in 3.9, Intel support in 3.12, MSVC in 3.13.
  # To reduce complexity of the logic involved here, we only use
  # CheckIPOSupported for 3.13+.  Otherwise, manually test flags.
  if (CMAKE_VERSION VERSION_GREATER_EQUAL 3.13)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT nanogui_has_ipo OUTPUT nanogui_ipo_error)
    if (nanogui_has_ipo)
      message(STATUS "NanoGUI: IPO support enabled.")
      foreach (tgt nanogui nanogui-obj nanogui-python nanogui-python-obj)
        if (TARGET ${tgt})
          set_target_properties(${tgt}
            PROPERTIES
              INTERPROCEDURAL_OPTIMIZATION_RELEASE ON
              INTERPROCEDURAL_OPTIMIZATION_MINSIZEREL ON
              INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO ON
          )
        endif()
      endforeach()
    else()
      message(STATUS "NanoGUI: IPO not supported. ${nanogui_ipo_error}")
    endif()
  else()
    if (MSVC)
      message(STATUS "NanoGUI: IPO support enabled.")
      target_compile_options(nanogui-private-interface
        INTERFACE
          $<$<CONFIG:Release>:/GL>
          $<$<CONFIG:MinSizeRel>:/GL>
          $<$<CONFIG:RelWithDebInfo>:/GL>
      )
      target_link_options(nanogui-private-interface
        INTERFACE
          $<$<CONFIG:Release>:/LTCG>
          $<$<CONFIG:MinSizeRel>:/LTCG>
          $<$<CONFIG:RelWithDebInfo>:/LTCG>
      )
    else()
      if (NOT CMAKE_CXX_FLAGS MATCHES "-flto")
        if (CMAKE_CXX_COMPILER_ID MATCHES Clang)
          set(ipo_cxx_flags "-flto=thin")
          set(ipo_linker_flags "-flto=thin")
        else()
          set(ipo_cxx_flags "-flto -fno-fat-lto-objects")
          set(ipo_linker_flags "-flto")
        endif()
        check_cxx_compiler_and_linker_flags(
          nanogui_has_ipo "${ipo_cxx_flags}" "${ipo_linker_flags}"
        )
        if (nanogui_has_ipo)
          message(STATUS "NanoGUI: IPO support enabled.")
          # Generator expressions need a list to expand as separate arguments.
          string(REPLACE " " ";" ipo_cxx_flags "${ipo_cxx_flags}")
          string(REPLACE " " ";" ipo_linker_flags "${ipo_linker_flags}")
          target_compile_options(nanogui-private-interface
            INTERFACE
              $<$<CONFIG:Release>:${ipo_cxx_flags}>
              $<$<CONFIG:MinSizeRel>:${ipo_cxx_flags}>
              $<$<CONFIG:RelWithDebInfo>:${ipo_cxx_flags}>
          )
          target_link_options(nanogui-private-interface
            INTERFACE
              $<$<CONFIG:Release>:${ipo_linker_flags}>
              $<$<CONFIG:MinSizeRel>:${ipo_linker_flags}>
              $<$<CONFIG:RelWithDebInfo>:${ipo_linker_flags}>
          )
        else()
          message(STATUS "NanoGUI: IPO not supported.")
        endif()
      endif()
    endif()
  endif()
endif()

################################################################################
# Compiler / IDE specific customizations.                                      #
################################################################################
# If Clang, use -stdlib=libc++ by default unless e.g., -stdlib=libstdc++ is
# already in CMAKE_CXX_FLAGS.
if (CMAKE_CXX_COMPILER_ID MATCHES Clang AND NANOGUI_USE_LIBCXX AND
    NOT CMAKE_CXX_FLAGS MATCHES "-stdlib=")
  set(libcxx_cxx_flags "-stdlib=libc++")
  set(libcxx_linker_flags "-stdlib=libc++")
  check_cxx_compiler_and_linker_flags(
    nanogui_has_libcxx "${libcxx_cxx_flags}" "${libcxx_linker_flags}"
  )
  if (nanogui_has_libcxx)
    set(libcxx_linker_flags "-stdlib=libc++ -lc++abi")
    check_cxx_compiler_and_linker_flags(
      nanogui_has_libcxx_abi "${libcxx_cxx_flags}" "${libcxx_linker_flags}"
    )
    if (nanogui_has_libcxx_abi)
      message(STATUS "NanoGUI: using libc++ and libc++abi.")
    else()
      # -lc++abi test failed, remove from linker flags
      message(STATUS "NanoGUI: using libc++.")
      set(libcxx_linker_flags "-stdlib=libc++")
    endif()

    # Generator expressions need a list to expand as separate arguments.
    string(REPLACE " " ";" libcxx_cxx_flags "${libcxx_cxx_flags}")
    string(REPLACE " " ";" libcxx_linker_flags "${libcxx_linker_flags}")
    target_compile_options(nanogui-interface
      INTERFACE
        $<$<COMPILE_LANGUAGE:CXX>:${libcxx_cxx_flags}>
    )
    target_link_options(nanogui-interface
      INTERFACE
        $<$<COMPILE_LANGUAGE:CXX>:${libcxx_linker_flags}>
    )
  else()
    message(STATUS "NanoGUI: NOT using libc++.")
  endif()
endif()

if (MSVC)
  # Disable annoying MSVC warnings (all targets)
  target_compile_definitions(nanogui-private-interface INTERFACE _CRT_SECURE_NO_WARNINGS)

  # Parallel build on MSVC (all targets)
  target_compile_options(nanogui-private-interface INTERFACE /MP)

  # Use default exception handling method if not provided.
  # https://docs.microsoft.com/en-us/cpp/build/reference/eh-exception-handling-model
  if (NOT CMAKE_CXX_FLAGS MATCHES /EH)
    target_compile_options(nanogui-private-interface INTERFACE /EHsc)
  endif()

  # NOTE: CMake 3.15 introduces MSVC_RUNTIME_LIBRARY.  Use the property when available.
  # Cannot set MSVC_RUNTIME_LIBRARY property on interface libraries.
  if (POLICY CMP0091)
    if (BUILD_SHARED_LIBS)
      # Compiles with /MD, or /MDd (debug)
      set(msvc_dll "DLL")
    else()
      # Compiles with /MT, or /MTd (debug)
      set(msvc_dll "")
    endif()
    foreach (tgt nanogui nanogui-obj nanogui-python nanogui-python-obj)
      if (TARGET ${tgt})
        set_target_properties(${tgt}
          PROPERTIES
            MSVC_RUNTIME_LIBRARY MultiThreaded$<$<CONFIG:Debug>>${msvc_dll}
        )
      endif()
    endforeach()
  else()
    if (BUILD_SHARED_LIBS)
      target_compile_options(nanogui-interface INTERFACE /MD$<$<CONFIG:Debug>:d>)
    else()
      target_compile_options(nanogui-interface INTERFACE /MT$<$<CONFIG:Debug>:d>)
    endif()
  endif()
endif()

if (APPLE)
  # Use automatic reference counting for Objective-C portions
  target_compile_options(nanogui-private-interface INTERFACE -fobjc-arc)
endif()

# XCode has a serious bug where the XCode project produces an invalid target
# that will not get linked if it consists only of objects from object libraries,
# it will not generate any products (executables, libraries). The only work
# around is to add a dummy source file to the library definition. This is an
# XCode, not a CMake bug. See: https://itk.org/Bug/view.php?id=14044
if (CMAKE_GENERATOR STREQUAL Xcode)
  set(xcode_dummy "${CMAKE_CURRENT_BINARY_DIR}/generated/src/xcode_dummy.cpp")
  file(WRITE ${xcode_dummy} "")
  target_sources(nanogui PRIVATE ${xcode_dummy})
endif()

################################################################################
# Platform specific customizations.                                            #
################################################################################
if (CMAKE_SYSTEM_NAME MATCHES "BSD")
  target_include_directories(nanogui-interface
    INTERFACE
      $<BUILD_INTERFACE:/usr/local/include>
      $<INSTALL_INTERFACE:/usr/local/include>
  )
  target_link_directories(nanogui-interface
    INTERFACE
      $<BUILD_INTERFACE:/usr/local/lib>
      $<INSTALL_INTERFACE:/usr/local/lib>
  )
  if (CMAKE_SYSTEM_NAME MATCHES "OpenBSD")
    target_include_directories(nanogui-interface
      INTERFACE
        $<BUILD_INTERFACE:/usr/X11R6/include>
        $<INSTALL_INTERFACE:/usr/X11R6/include>
    )
    target_link_directories(nanogui-interface
      INTERFACE
        $<BUILD_INTERFACE:/usr/X11R6/lib>
        $<INSTALL_INTERFACE:/usr/X11R6/lib>
    )
  endif()
endif()
