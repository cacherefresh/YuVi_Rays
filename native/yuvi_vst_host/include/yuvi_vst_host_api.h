#pragma once

#include <stdint.h>

// C ABI for the native VST3/AU host, consumed from Dart via dart:ffi
// (see packages/yuvi_vst_engine). Kept as plain C so the FFI binding
// generator (package:ffigen) can parse it directly.

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to a loaded plugin instance.
typedef void* YvhPluginHandle;

// Scans a directory for VST3 (Windows/macOS) and AU (macOS) plugins.
// Returns a heap-allocated, null-terminated UTF-8 JSON array of
// {name, path, format} — caller must free it with yvh_free_string.
char* yvh_scan_plugins(const char* directory);

// Loads a plugin by its scanned path. Returns a null handle on failure
// (including "not implemented yet" — see README.md).
YvhPluginHandle yvh_load_plugin(const char* path);
void yvh_unload_plugin(YvhPluginHandle handle);

// Channel gain, 0.0-1.0 linear.
void yvh_set_gain(YvhPluginHandle handle, double normalized);

// Current output level in dBFS, matching YuViDVS.getMasterLevel()'s
// convention (-100 = silent) so both bridges read the same way on the
// Dart side.
double yvh_get_level(YvhPluginHandle handle);

// Opens/closes the plugin's own native editor window. This is a
// synced-position child window, not an embedded Flutter widget — see
// README.md's "Editor UI" note before wiring a "pop out" affordance to it.
void yvh_open_editor(YvhPluginHandle handle);
void yvh_close_editor(YvhPluginHandle handle);

// Maps a MIDI CC number to a plugin parameter index (Phase 3 — MIDI
// mapping in yuvi_midi_engine handles app controls; this is the plugin-
// parameter side of that, kept in the audio thread for latency).
void yvh_map_midi_cc(YvhPluginHandle handle, int cc_number, int32_t parameter_index);

void yvh_free_string(char* str);

#ifdef __cplusplus
}
#endif
