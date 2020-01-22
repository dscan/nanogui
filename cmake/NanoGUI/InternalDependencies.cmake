################################################################################
# Convert fonts into resource header / c++ files to compile into NanoGUI.      #
################################################################################
# Gather font resource files to embed.
file(GLOB resources "${CMAKE_CURRENT_SOURCE_DIR}/resources/*.ttf")

# Concatenate resource files into a comma separated string.
string(REGEX REPLACE "([^\\]|^);" "\\1," resources_string "${resources}")
string(REGEX REPLACE "[\\](.)" "\\1" resources_string "${resources_string}")

# Populate the command-line arguments for running bin2c.
set(nanogui_bin2c_header "${CMAKE_CURRENT_BINARY_DIR}/generated/include/nanogui/resources.h")
set(nanogui_bin2c_source "${CMAKE_CURRENT_BINARY_DIR}/generated/src/resources.cpp")
set(nanogui_bin2c_cmdline
  -DOUTPUT_H="${nanogui_bin2c_header}"
  -DOUTPUT_C="${nanogui_bin2c_source}"
  -DINPUT_FILES="${resources_string}"
  -P "${CMAKE_CURRENT_SOURCE_DIR}/resources/bin2c.cmake"
)

# Create the custom command to run bin2c.
add_custom_command(
  # Output informs CMake that this command generates these files, which is
  # needed to add it to the `target_sources` of a target.
  OUTPUT
    ${nanogui_bin2c_header}
    ${nanogui_bin2c_source}
  COMMAND
    ${CMAKE_COMMAND}
  ARGS
    ${nanogui_bin2c_cmdline}
  # Trigger a rebuild if/when font files change.
  DEPENDS
    ${resources}
  COMMENT
    "NanoGUI: generating font resources."
)

# Add the output files to nanogui object library.
target_sources(nanogui-obj PRIVATE
  ${nanogui_bin2c_header}
  ${nanogui_bin2c_source}
)

# The generated directory is only needed as an include directory at build time.
# <nanogui/resources.h> will be installed to the same location as other headers.
target_include_directories(nanogui-interface
  INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/generated/include>
)
if (NANOGUI_INSTALL)
  install(
    FILES ${nanogui_bin2c_header}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/nanogui
  )
endif()

# Create a custom target that DEPENDS on the OUTPUT of the bin2c custom command
# so that we can force nanogui-obj and nanogui-python-obj to build _after_ these
# have been generated.
# NOTE: PRE_BUILD for add_custom_command not sufficient (not always supported).
add_custom_target(nanogui-resources
  DEPENDS
    ${nanogui_bin2c_header}
    ${nanogui_bin2c_source}
)
add_dependencies(nanogui-obj nanogui-resources)
if (TARGET nanogui-python-obj)
  add_dependencies(nanogui-python-obj nanogui-resources)
endif()

################################################################################
# Coordinate dependencies between nanogui targets.                             #
################################################################################
# CMake 3.12+ has better support for object libraries.
if (CMAKE_VERSION VERSION_GREATER_EQUAL 3.12)
  # Setup includes / compile definitions for compiling the object files.
  foreach (tgt nanogui-obj nanogui-python-obj)
    if (TARGET ${tgt})
      target_link_libraries(${tgt} PUBLIC nanogui-interface)
      target_link_libraries(${tgt} PRIVATE nanogui-private-interface)
    endif()
  endforeach()

  # Linking against an object library will propagate usage requirements as well
  # as consume the objects.
  target_link_libraries(nanogui PUBLIC nanogui-obj)
  if (NANOGUI_BUILD_PYTHON)
    target_link_libraries(nanogui-python PUBLIC nanogui-python-obj)
  endif()
else()
  # Prior to 3.12, object libraries cannot be used in target_link_libraries, so
  # we need to set things for both the "real" libs as well as object libs.
  foreach (tgt nanogui nanogui-python)
    if (TARGET ${tgt})
      target_link_libraries(${tgt} PUBLIC nanogui-interface)
      target_link_libraries(${tgt} PRIVATE nanogui-private-interface)
    endif()
  endforeach()

  # Main libs have the correct usage requirements.  Now set them for object libs.
  foreach (tgt nanogui-obj nanogui-python-obj)
    if (TARGET ${tgt})
      target_include_directories(${tgt}
        PUBLIC
          $<TARGET_PROPERTY:nanogui-interface,INTERFACE_INCLUDE_DIRECTORIES>
        PRIVATE
          $<TARGET_PROPERTY:nanogui-private-interface,INTERFACE_INCLUDE_DIRECTORIES>
      )
      target_compile_definitions(${tgt}
        PUBLIC
          $<TARGET_PROPERTY:nanogui-interface,INTERFACE_COMPILE_DEFINITIONS>
        PRIVATE
          $<TARGET_PROPERTY:nanogui-private-interface,INTERFACE_COMPILE_DEFINITIONS>
      )
    endif()
  endforeach()

  # Last but not least, make the main libraries consume the objects.
  target_sources(nanogui PRIVATE $<TARGET_OBJECTS:nanogui-obj>)
  target_sources(nanogui-python PRIVATE $<TARGET_OBJECTS:nanogui-python-obj>)
endif()

# NanoGUI python bindings link against the main lib.
if (TARGET nanogui-python)
  target_link_libraries(nanogui-python PUBLIC nanogui)
endif()
