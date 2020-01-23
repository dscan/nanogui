# This file is included with -DNANOGUI_DEV=ON, do not use this in parent
# projects.  Compile warnings on, where warnings are errors.
if (NANOGUI_HAS_PARENT OR NANOGUI_INSTALL)
  # Flags end up in the *public* interface, which is bad for all usage cases
  # other than testing NanoGUI packaging / examples.
  # NOTE: do not WARNING here, we fail CI builds on CMake warnings.
  message(
    "(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)\n"
    "(!) NANOGUI_DEV=ON but NanoGUI has a parent or is being installed.   (!)\n"
    "(!) This should *ONLY* be done if you are developing NanoGUI.        (!)\n"
    "(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)(!)\n"
  )
endif()

if (MSVC)
  # /W3 may be added by default, remove it in favor of /W4.
  if (CMAKE_CXX_FLAGS MATCHES "/W[0-4]")
    string(REGEX REPLACE "/W[0-4]" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
  endif()
  target_compile_options(nanogui-interface INTERFACE /W4 /WX)
  target_link_options(nanogui-interface INTERFACE /WX)
else()
  # Clang, GCC, Intel, etc.
  foreach (flag -Wall -Wextra -Werror)
    check_cxx_compiler_flag(${flag} have_flag)
    if (have_flag)
      target_compile_options(nanogui-interface INTERFACE ${flag})
    endif()
  endforeach()
endif()

# Create documentation for python plugin (optional target for developers)
add_custom_target(mkdoc COMMAND
  python3 ${CMAKE_CURRENT_SOURCE_DIR}/docs/mkdoc_rst.py
    -I$<JOIN:$<TARGET_PROPERTY:nanogui,INTERFACE_INCLUDE_DIRECTORIES>,-I>
    -D$<JOIN:$<TARGET_PROPERTY:nanogui,INTERFACE_COMPILE_DEFINITIONS>,-D>
    -DDOXYGEN_DOCUMENTATION_BUILD
    ${CMAKE_CURRENT_SOURCE_DIR}/include/nanogui/*.h
    > ${CMAKE_CURRENT_SOURCE_DIR}/python/py_doc.h
)
