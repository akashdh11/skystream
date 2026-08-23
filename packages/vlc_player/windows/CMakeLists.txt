# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "vlc_player")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "vlc_player_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "../src/native/vlc_player_core.cc"
  "../src/native/vlc_player_core.h"
  "../src/native/vlc_player_types.h"
  "vlc_player_plugin.cpp"
  "vlc_player_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/vlc_player/vlc_player_plugin_c_api.h"
  "vlc_player_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "vlc_player currently supports Windows x64 builds only.")
endif()

set(VLC_PLAYER_VLC_VERSION "3.0.21")
set(VLC_PLAYER_VLC_ARCHIVE "vlc-${VLC_PLAYER_VLC_VERSION}-win64.7z")
set(VLC_PLAYER_VLC_URL
  "https://download.videolan.org/pub/videolan/vlc/${VLC_PLAYER_VLC_VERSION}/win64/${VLC_PLAYER_VLC_ARCHIVE}")
set(VLC_PLAYER_VLC_SHA256
  "9d2b24d6bc4196b3da8d181a3878678ba272e2a7690321f8826da76a69b2fb9c")
set(VLC_PLAYER_VLC_DOWNLOAD_DIR "${CMAKE_CURRENT_BINARY_DIR}/vlc")
set(VLC_PLAYER_VLC_ARCHIVE_PATH
  "${VLC_PLAYER_VLC_DOWNLOAD_DIR}/${VLC_PLAYER_VLC_ARCHIVE}")
set(VLC_PLAYER_RUNTIME_DIR
  "${VLC_PLAYER_VLC_DOWNLOAD_DIR}/vlc-${VLC_PLAYER_VLC_VERSION}")

if(NOT EXISTS "${VLC_PLAYER_RUNTIME_DIR}/libvlc.dll" OR
   NOT EXISTS "${VLC_PLAYER_RUNTIME_DIR}/libvlccore.dll" OR
   NOT EXISTS "${VLC_PLAYER_RUNTIME_DIR}/plugins")
  message(STATUS "Downloading VLC ${VLC_PLAYER_VLC_VERSION} Windows runtime")
  file(MAKE_DIRECTORY "${VLC_PLAYER_VLC_DOWNLOAD_DIR}")
  file(DOWNLOAD
    "${VLC_PLAYER_VLC_URL}"
    "${VLC_PLAYER_VLC_ARCHIVE_PATH}"
    EXPECTED_HASH "SHA256=${VLC_PLAYER_VLC_SHA256}"
    SHOW_PROGRESS
    STATUS vlc_player_download_status
    TLS_VERIFY ON)
  list(GET vlc_player_download_status 0 vlc_player_download_code)
  list(GET vlc_player_download_status 1 vlc_player_download_message)
  if(NOT vlc_player_download_code EQUAL 0)
    message(FATAL_ERROR
      "Failed to download VLC Windows runtime from ${VLC_PLAYER_VLC_URL}: "
      "${vlc_player_download_message}")
  endif()

  file(REMOVE_RECURSE "${VLC_PLAYER_RUNTIME_DIR}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "${VLC_PLAYER_VLC_ARCHIVE_PATH}"
    WORKING_DIRECTORY "${VLC_PLAYER_VLC_DOWNLOAD_DIR}"
    RESULT_VARIABLE vlc_player_extract_result)
  if(NOT vlc_player_extract_result EQUAL 0)
    message(FATAL_ERROR
      "Failed to extract VLC Windows runtime from ${VLC_PLAYER_VLC_ARCHIVE_PATH}.")
  endif()
endif()

set(VLC_PLAYER_LIBVLC_MEDIA_HEADER
  "${VLC_PLAYER_RUNTIME_DIR}/sdk/include/vlc/libvlc_media.h")
if(EXISTS "${VLC_PLAYER_LIBVLC_MEDIA_HEADER}")
  file(READ "${VLC_PLAYER_LIBVLC_MEDIA_HEADER}" vlc_player_libvlc_media)
  set(vlc_player_libvlc_media_patched "${vlc_player_libvlc_media}")
  string(REPLACE
    "typedef SSIZE_T ssize_t;"
    "#if _MSC_VER < 1900\ntypedef SSIZE_T ssize_t;\n#endif"
    vlc_player_libvlc_media_patched
    "${vlc_player_libvlc_media_patched}")
  string(REPLACE
    "#ifndef _SSIZE_T_DEFINED\n#define _SSIZE_T_DEFINED\ntypedef SSIZE_T ssize_t;\n#endif"
    "#if _MSC_VER < 1900\ntypedef SSIZE_T ssize_t;\n#endif"
    vlc_player_libvlc_media_patched
    "${vlc_player_libvlc_media_patched}")
  if(NOT vlc_player_libvlc_media STREQUAL vlc_player_libvlc_media_patched)
    file(WRITE "${VLC_PLAYER_LIBVLC_MEDIA_HEADER}"
      "${vlc_player_libvlc_media_patched}")
  endif()
endif()

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(vlc_player_bundled_libraries
  ""
  PARENT_SCOPE
)
if(EXISTS "${VLC_PLAYER_RUNTIME_DIR}/libvlc.dll" AND
   EXISTS "${VLC_PLAYER_RUNTIME_DIR}/libvlccore.dll" AND
   EXISTS "${VLC_PLAYER_RUNTIME_DIR}/plugins" AND
   EXISTS "${VLC_PLAYER_RUNTIME_DIR}/sdk/include/vlc/vlc.h" AND
   EXISTS "${VLC_PLAYER_RUNTIME_DIR}/sdk/lib/libvlc.lib")
  target_include_directories(${PLUGIN_NAME} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../src/native"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libvlcpp"
    "${VLC_PLAYER_RUNTIME_DIR}/sdk/include")
  target_link_libraries(${PLUGIN_NAME} PRIVATE
    "${VLC_PLAYER_RUNTIME_DIR}/sdk/lib/libvlc.lib")

  file(GLOB VLC_PLAYER_RUNTIME_DLLS "${VLC_PLAYER_RUNTIME_DIR}/*.dll")
  set(vlc_player_bundled_libraries
    ${VLC_PLAYER_RUNTIME_DLLS}
    PARENT_SCOPE
  )

  if(DEFINED BINARY_NAME)
    foreach(vlc_player_runtime_directory hrtfs locale lua plugins skins)
      if(EXISTS "${VLC_PLAYER_RUNTIME_DIR}/${vlc_player_runtime_directory}")
        add_custom_target(
          ${PLUGIN_NAME}_copy_${vlc_player_runtime_directory} ALL
          COMMAND "${CMAKE_COMMAND}" -E copy_directory
          "${VLC_PLAYER_RUNTIME_DIR}/${vlc_player_runtime_directory}"
          "$<TARGET_FILE_DIR:${BINARY_NAME}>/${vlc_player_runtime_directory}")
      endif()
    endforeach()
  endif()
else()
  message(FATAL_ERROR
    "Incomplete downloaded VLC Windows runtime in ${VLC_PLAYER_RUNTIME_DIR}. "
    "Expected libvlc.dll, libvlccore.dll, plugins/, sdk/include, and "
    "sdk/lib/libvlc.lib.")
endif()

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.zip
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/vlc_player_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_compile_definitions(${TEST_RUNNER} PRIVATE VLC_PLAYER_TESTING)
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(${TEST_RUNNER} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/native"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libvlcpp"
  "${VLC_PLAYER_RUNTIME_DIR}/sdk/include")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE
  "${VLC_PLAYER_RUNTIME_DIR}/sdk/lib/libvlc.lib")
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)
foreach(vlc_player_runtime_dll ${VLC_PLAYER_RUNTIME_DLLS})
  add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${vlc_player_runtime_dll}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
  )
endforeach()
foreach(vlc_player_runtime_directory hrtfs locale lua plugins skins)
  if(EXISTS "${VLC_PLAYER_RUNTIME_DIR}/${vlc_player_runtime_directory}")
    add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
      COMMAND "${CMAKE_COMMAND}" -E copy_directory
      "${VLC_PLAYER_RUNTIME_DIR}/${vlc_player_runtime_directory}"
      "$<TARGET_FILE_DIR:${TEST_RUNNER}>/${vlc_player_runtime_directory}")
  endif()
endforeach()

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
