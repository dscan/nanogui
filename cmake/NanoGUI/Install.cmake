include(CMakePackageConfigHelpers)

# Install the project header files.
install(
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/nanogui
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  FILES_MATCHING PATTERN "*.h"
)

# Install the project targets.
install(
  TARGETS
    nanogui
    nanogui-obj
    nanogui-interface
    nanogui-private-interface
  EXPORT nanogui-targets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Export the project targets for `find_package` calls of consumers.
install(
  EXPORT nanogui-targets
  # NOTE: this filename is used in cmake/NanoGUI/nanogui-config.cmake.in.
  FILE nanogui-targets.cmake
  NAMESPACE nanogui::
  DESTINATION ${NANOGUI_INSTALL_CONFIGDIR}/nanogui
)

# Generate the project version information.
write_basic_package_version_file(
  ${CMAKE_CURRENT_BINARY_DIR}/nanogui-config-version.cmake
  VERSION ${PROJECT_VERSION}
  # NanoGUI 0.1.0 and 1.0.0 will not be compatible.
  COMPATIBILITY SameMajorVersion
)

# Try and obtain the commit being compiled to install.  This will be saved in
# nanogui-config.cmake if recovered.
find_program(git_exe git)
set(NANOGUI_REVISION "NOTFOUND")
if (git_exe)
  execute_process(
    COMMAND
      ${git_exe} log -1 --pretty=%H
    WORKING_DIRECTORY
      ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE
      git_log_failed
    OUTPUT_VARIABLE
      NANOGUI_REVISION
    ERROR_VARIABLE
      git_log_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
  )
  if (git_log_failed)
    message(STATUS "NanoGUI: unable to recover HEAD commit. ${git_log_error}")
    set(NANOGUI_REVISION "NOTFOUND")
  else()
    message(STATUS "NanoGUI: HEAD commit is ${NANOGUI_REVISION}.")
  endif()
endif()

# Generate the project config file.
configure_package_config_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/cmake/NanoGUI/nanogui-config.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/nanogui-config.cmake
  INSTALL_DESTINATION ${NANOGUI_INSTALL_CONFIGDIR}/nanogui/nanogui-config.cmake
  NO_CHECK_REQUIRED_COMPONENTS_MACRO
)

# Install the generated CMake config files.
foreach (genfile config config-version)
  install(
    FILES ${CMAKE_CURRENT_BINARY_DIR}/nanogui-${genfile}.cmake
    DESTINATION ${NANOGUI_INSTALL_CONFIGDIR}/nanogui
  )
endforeach()


