# This file is included with -DNANOGUI_DEV=ON, do not use this in parent
# projects.  Compile warnings on, where warnings are errors.
if (MSVC)
  # /W3 may be added by default, remove it in favor of /W4.
  if (CMAKE_CXX_FLAGS MATCHES "/W[0-4]")
    string(REGEX REPLACE "/W[0-4]" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
  endif()
  target_compile_options(nanogui-private-interface INTERFACE /W4 /WX)
elseif (CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID MATCHES "GNU")
  target_compile_options(nanogui-private-interface INTERFACE -Wall -Wextra -Werror)
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
