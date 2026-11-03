cmake_minimum_required(VERSION 3.22)
project(yuvi_vst_host VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Phase 1: builds today as a standalone stub library, no external deps —
# this just proves the FFI/CMake plumbing end to end.
add_library(yuvi_vst_host SHARED
  src/PluginHost.cpp
)

target_include_directories(yuvi_vst_host PUBLIC include)

# ── JUCE (Phase 1 real implementation onward) ────────────────────────────
# Uncomment once PluginHost.cpp actually calls into JUCE's
# AudioPluginFormatManager. JUCE is dual-licensed AGPLv3/commercial —
# read README.md's Licensing section before enabling this for a build
# you intend to distribute.
#
# include(FetchContent)
# FetchContent_Declare(
#   JUCE
#   GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
#   GIT_TAG        master
#   GIT_SHALLOW    TRUE
# )
# FetchContent_MakeAvailable(JUCE)
#
# target_link_libraries(yuvi_vst_host PRIVATE
#   juce::juce_audio_processors
#   juce::juce_audio_utils
# )
# target_compile_definitions(yuvi_vst_host PRIVATE
#   JUCE_PLUGINHOST_VST3=1
#   JUCE_PLUGINHOST_AU=1   # macOS only — harmless no-op on Windows
# )
