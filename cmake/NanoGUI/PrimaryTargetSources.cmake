# NOTE: please refer to the excellent article by Craig Scott explaining why this
# nanogui_target_sources is used.  See "Supporting CMake 3.12 And Earlier":
#
# https://crascit.com/2016/01/31/enhanced-source-file-handling-with-target_sources/
#
# NanoGUI makes additional assumptions to simplify the function:
# - No generator expressions allowed!
# - No absolute paths allowed (NanoGUI convention).
# - NanoGUI only uses PRIVATE sources.  Each ${ARGN} is assumed to be a file.
function(nanogui_target_sources tgt)
  # NOTE: use a function so that the policy scope is only relevant locally.
  if (POLICY CMP0076)
    cmake_policy(PUSH)
    cmake_policy(SET CMP0076 NEW)
    target_sources(${tgt} PRIVATE ${ARGN})
    cmake_policy(POP)
    return()
  endif()

  # NOTE: this file is being `include`ed from the top-level NanoGUI
  # CMakeLists.txt, which is why we can prefix CMAKE_CURRENT_SOURCE_DIR.
  set(nanogui_sources)
  foreach(src ${ARGN})
    list(APPEND nanogui_sources "${CMAKE_CURRENT_SOURCE_DIR}/${src}")
  endforeach()
  target_sources(${tgt} PRIVATE ${nanogui_sources})
endfunction()

# Main NanoGUI library
nanogui_target_sources(nanogui-obj
  # The core header files.
  include/nanogui/button.h
  include/nanogui/checkbox.h
  include/nanogui/colorpicker.h
  include/nanogui/colorwheel.h
  include/nanogui/combobox.h
  include/nanogui/common.h
  include/nanogui/formhelper.h
  include/nanogui/glcanvas.h
  include/nanogui/glutil.h
  include/nanogui/graph.h
  include/nanogui/imagepanel.h
  include/nanogui/imageview.h
  include/nanogui/label.h
  include/nanogui/layout.h
  include/nanogui/messagedialog.h
  include/nanogui/nanogui.h
  include/nanogui/opengl.h
  include/nanogui/popup.h
  include/nanogui/popupbutton.h
  include/nanogui/progressbar.h
  include/nanogui/screen.h
  include/nanogui/serializer/core.h
  include/nanogui/serializer/opengl.h
  include/nanogui/serializer/sparse.h
  include/nanogui/slider.h
  include/nanogui/stackedwidget.h
  include/nanogui/tabheader.h
  include/nanogui/tabwidget.h
  include/nanogui/textbox.h
  include/nanogui/theme.h
  include/nanogui/toolbutton.h
  include/nanogui/vscrollpanel.h
  include/nanogui/widget.h
  include/nanogui/window.h
  # The core source files.
  src/button.cpp
  src/checkbox.cpp
  src/colorpicker.cpp
  src/colorwheel.cpp
  src/combobox.cpp
  src/common.cpp
  src/glcanvas.cpp
  src/glutil.cpp
  src/graph.cpp
  src/imagepanel.cpp
  src/imageview.cpp
  src/label.cpp
  src/layout.cpp
  src/messagedialog.cpp
  src/popup.cpp
  src/popupbutton.cpp
  src/progressbar.cpp
  src/screen.cpp
  src/serializer.cpp
  src/slider.cpp
  src/stackedwidget.cpp
  src/tabheader.cpp
  src/tabwidget.cpp
  src/textbox.cpp
  src/theme.cpp
  src/vscrollpanel.cpp
  src/widget.cpp
  src/window.cpp
)

# Python library
if (NANOGUI_BUILD_PYTHON)
  nanogui_target_sources(nanogui-python-obj
    python/main.cpp
    python/constants_glfw.cpp
    python/constants_entypo.cpp
    python/eigen.cpp
    python/widget.cpp
    python/layout.cpp
    python/basics.cpp
    python/button.cpp
    python/tabs.cpp
    python/textbox.cpp
    python/theme.cpp
    python/glcanvas.cpp
    python/formhelper.cpp
    python/misc.cpp
    python/glutil.cpp
    python/nanovg.cpp
    python/python.h
    python/py_doc.h
  )
endif()
