# yuvi_vst_host

Native plugin-hosting engine for the YuVi Rays Desktop app (macOS/Windows) —
loads real VST3/AU plugin files and exposes them to Flutter via
`packages/yuvi_vst_engine` (`dart:ffi`). Not usable in the Flutter Web build:
browsers cannot execute native plugin binaries, which is why the AUX
channel on web is a virtual-audio-input strip instead (see the root
`DJ_INSTRUCTIONS.md`).

**Current status: Phase 1 stub.** Every function in `src/PluginHost.cpp`
compiles and returns honest "not implemented" values (empty plugin list,
null handle, -100 dBFS) — nothing here fabricates plugin data. Building it
today just proves the CMake → shared library → FFI plumbing works; it does
not host any actual plugins yet.

## Prerequisites (not set up in the environment this was scaffolded in)

- `cmake` ≥ 3.22
- macOS: full Xcode (not just Command Line Tools — `xcode-select -p` should
  point at `/Applications/Xcode.app/...`)
- Windows: Visual Studio 2022 with the "Desktop development with C++" workload
- JUCE (fetched automatically via CMake `FetchContent` once the commented-out
  block in `CMakeLists.txt` is enabled — no manual download needed)

## Licensing — decide before Phase 1 real implementation

- **VST3 SDK**: MIT-licensed (Steinberg relicensed it in October 2025) — no
  FOSS-compatibility issue.
- **AU (Audio Unit)**: Apple public framework, macOS-only, no licensing issue.
- **JUCE itself**: dual-licensed AGPLv3/commercial. The free tier requires
  the whole app to ship AGPLv3-compatible; a closed-source or more
  permissively-licensed distribution needs a paid JUCE subscription. YuVi
  Rays is described as FOSS, so the free tier is likely fine — confirm
  before Phase 1 lands rather than assuming.

## Phased plan

1. **Scan/load/passthrough** (~2-3 weeks) — real `AudioPluginFormatManager`
   integration, load a plugin, route its audio into the AUX channel's gain
   stage. No editor UI, no MIDI. This is the foundational multi-week
   effort — everything else builds on it.
2. **Native editor window** (~2-4 weeks, genuinely hard) — a plugin's own
   GUI (an NSView on macOS / HWND on Windows) **cannot be embedded inside
   Flutter's compositor** the way the AUX channel's own controls can be a
   draggable in-app panel. Realistic v1: a separate always-on-top native
   child window whose position is synced to the Flutter app window over a
   platform channel, so it *feels* attached even though it isn't a Flutter
   widget. Also covers macOS notarization/Gatekeeper handling for
   unsigned third-party plugins, and crash isolation (a bad plugin
   shouldn't take down the whole app — prototype an out-of-process host
   early rather than in-process loading).
3. **MIDI parameter mapping** (~1-2 weeks) — route a learned MIDI CC (via
   `yuvi_midi_engine`) to a plugin parameter index, applied directly in the
   audio thread via `yvh_map_midi_cc`.

## Module layout (as Phase 1 fills in)

- `include/yuvi_vst_host_api.h` — the C ABI Dart binds against via FFI.
- `src/PluginHost.cpp` — scan/load/format-manager logic.
- `src/AudioBridge.cpp` (not yet created) — buffer pull + mixing into the
  AUX channel bus.
- `src/EditorWindow.cpp` (not yet created) — native window management for
  Phase 2.
