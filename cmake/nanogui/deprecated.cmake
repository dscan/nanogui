# The CMake rewrite modifies, removes, and/or adds different options.  To help users
# understand, hard error on deprecated options (to avoid e.g., build errors from lists
# that are no longer populated in PARENT_SCOPE).
#
# Use SEND_ERROR to fail, but allow configuration to continue.  In this manner consumers
# making the switch should be notified of all required updates.
# Deprecated options.
if (DEFINED NANOGUI_BUILD_SHARED)
  message(SEND_ERROR "NANOGUI_BUILD_SHARED is no longer an option.  Configure with "
                     "-DBUILD_SHARED_LIBS=ON to get a shared library.")
endif()

if (DEFINED NANOGUI_PYBIND11_DIR)
  message(SEND_ERROR "NANOGUI_PYBIND11_DIR is no longer used.  Ensure "
                     "find_package(pybind11) will find the correct location.")
endif()

if (DEFINED NANOGUI_BUILD_EXAMPLE)
  message(SEND_ERROR "NANOGUI_BUILD_EXAMPLE is now plural, please use "
                     "NANOGUI_BUILD_EXAMPLES with an S at the end.")
endif()

# In the days of yore (CMake 2.x), the pattern was to populate various lists to the
# PARENT_SCOPE and consumers would use these to include / define / link.  Everything is
# target based now, meaning these lists are no longer populated.  We can aid parent
# projects in catching this early by setting a variable watch!
function(nanogui_deprecated var access value current_list_file stack)
  message(SEND_ERROR "${var} is no longer populated!  Remove its use, and simply "
                     "target_link_libraries(your-tgt PUBLIC nanogui::nanogui).")
endfunction()
variable_watch(NANOGUI_EXTRA_DEFS nanogui_deprecated)
variable_watch(NANOGUI_EXTRA_INCS nanogui_deprecated)
variable_watch(NANOGUI_EXTRA_LIBS nanogui_deprecated)
