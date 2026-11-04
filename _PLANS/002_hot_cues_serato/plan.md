# Plan 002 — Four hot cues per track, with Serato cue import

**Status:** Read side in progress (2026-11-03): the Serato cue reader, 4 hot cues per deck in memory, and keyboard, pad and on-screen controls. **Saving is deferred to [plan 005](../005_write-perm_storage-savefeature/plan.md)**, covering persistence (phase 3 below) and write-back (phase 5). Until then, hot cues last only until reload.
**Source request:** `_DEVELOPER_NOTES/_NON_HUMAN_NOTES/feature_requests_and_findings.md` FR-004

---

## 1. Goal

Each deck gets 4 hot cue buttons, like Serato. Hot cues are saved per track and come back the next time that track is loaded. When an MP3 already has Serato cue points, YuVi Rays reads them.

The existing single **CUE** stays. It works as the main cue, the way Serato and CDJs keep a main cue separate from hot cues.

---

## 2. How Serato stores cues in an MP3

Serato writes cues into the MP3's ID3v2 tag as `GEOB` (general encapsulated object) frames.

| Frame description | Format | Use |
|---|---|---|
| `Serato Markers2` | Base64 text wrapping a binary list of entries | **Primary.** Current Serato DJ versions write this. |
| `Serato Markers_` | Older fixed-size binary records | Fallback for older libraries. Later phase. |

A `Serato Markers2` payload decodes to a 2-byte version header (`0x01 0x01`), then repeated entries:

```
name (ASCII, null-terminated)   e.g. "CUE", "COLOR", "LOOP", "BPMLOCK"
length (uint32, big-endian)
data (length bytes)
```

A `CUE` entry's data:

```
0x00
index      u8        hot cue slot 0..7
position   u32 BE    milliseconds from track start
0x00
color      3 bytes   RGB
0x00 0x00
name       UTF-8, null-terminated
```

Serato has 8 hot cue slots. YuVi Rays shows slots 0–3 and keeps 4–7 so they aren't lost.

Out of scope: Serato tags in FLAC, M4A and AIFF, which store them differently. Only MP3 is loaded today.

---

## 3. Design

### New reusable package `packages/yuvi_track_metadata`

Pure Dart. No Flutter, no web, no audio dependency, so it runs in VM tests and other projects can use it.

```dart
class HotCue {
  final int index;          // 0..7
  final Duration position;
  final int? colorArgb;
  final String? label;
}

abstract interface class CueSource {
  List<HotCue> readCues(Uint8List fileBytes);
}

class Id3v2Reader { ... }                 // finds GEOB frames, handles v2.3 and v2.4 sizes
class SeratoMarkers2Decoder implements CueSource { ... }
```

### Cue storage in the app

| Store | Key | Notes |
|---|---|---|
| **IndexedDB (recommended)** | SHA-1 of the file bytes | Works for local files and bundled assets. Never touches the user's file. |
| localStorage | same | Simpler, 5 MB limit. Fine for cues alone. |

Load order when a track loads:
1. Saved YuVi cues for this file's hash, if any.
2. Otherwise Serato cues read from the file.
3. Otherwise empty.

### Engine and bridge

- `yuvi_bridge.js` gets `jumpToSeconds(deckId, seconds)`. Hot cue logic stays in Dart. The bridge only seeks.
- `DeckState` gets `List<HotCue?> hotCues` with 4 slots.
- `DeckAudioController` gets `setHotCue(slot)`, `jumpToHotCue(slot)` and `clearHotCue(slot)`.

### Commands (extends the plan 001 contract)

`SetHotCue(deck, slot)`, `JumpToHotCue(deck, slot)`, `ClearHotCue(deck, slot)`.

### UI

A row of 4 coloured buttons under each deck's transport. An empty slot sets the cue. A filled slot jumps to it. Shift + click clears it. Cue markers also appear on the waveform.

---

## 4. Better way to consider: writing cues back into the MP3

You asked for cues saved **to the track**. A browser can write back into the original file, but only in Chrome, through the File System Access API. The file must be opened with `showOpenFilePicker` instead of the current upload picker.

| Option | Pros | Cons |
|---|---|---|
| A. Browser storage only (recommended first) | Safe. Simple. Works on GitHub Pages. | Cues stay in that browser. Serato won't see YuVi cues. |
| B. Write a `Serato Markers2` frame back into the file | Truly saved to the track. Serato sees YuVi cues. | Chrome only. Rewriting the ID3 tag can damage a user's Serato library if the encoder is wrong. Needs a backup copy and strict tests. |
| C. "Export MP3 with cues" download | No in-place risk. | Makes a second copy of the file. |

Recommendation: ship A, then add B as an opt-in setting once the decoder and encoder round-trip real Serato files byte-for-byte.

---

## 5. Phases

1. `yuvi_track_metadata`: ID3v2 reader and `Serato Markers2` decoder, with unit tests against real Serato-tagged MP3 headers.
2. Hot cue state, commands, bridge seek, and the 4-button UI. Cues are in memory only.
3. Persistence in IndexedDB keyed by file hash. Import Serato cues on load.
4. Hardware mapping: hot cue keys and pads.
5. Optional: write-back to the file (option B), behind a setting.

---

## 6. Open questions for Rob

1. **Write back to the file?** Is browser storage acceptable to start (option A), or must cues live inside the MP3 from day one (option B)?
2. **Keyboard keys for hot cues.** Proposal: `1 2 3 4` for Deck A and `7 8 9 0` for Deck B.
3. **Pads.** An 8-pad controller is already used for transport in plan 001. Options are a pad-bank switch, or using MPD226 pads 9–16 for hot cues.
4. **Sample files.** Can you share 2–3 MP3s that Serato has written cues to? They are needed to test the decoder. They don't have to be committed.

---

## 7. Build log

**2026-11-03. Read side built (Rob: "do the rest of the readable and controller stuff now").**

| Part | Where |
|---|---|
| ID3 GEOB frames, `Serato Markers2` decoder, `HotCue` model | `packages/yuvi_track_metadata` (14 tests, including Serato's base64 quirk) |
| 4 hot cue slots per deck. Serato slots 0–3 load with the track. | `DeckState.hotCues`, `DeckAudioController.triggerHotCue` / `clearHotCue` |
| Commands `TriggerHotCue` and `ClearHotCue`; pad `slot` field; keys `1`–`4` and `7`–`0`, with Shift to clear | `packages/yuvi_input` |
| MPK Mini Mk II pad bank B = hot cues: bottom row Deck A, top row Deck B | `assets/midi_profiles/akai_mpk_mini_mk2.yaml` |
| Hot cue buttons and numbered waveform flags | `yuvi_controls/HotCuePads`, `yuvi_waveform` strip |

Q2 and Q3 resolved as: keys `1 2 3 4` / `7 8 9 0` as proposed, and pads on bank B. Bank B's notes 32–39 don't clash with the piano keys.

Not built, moved to plan 005: persistence (phase 3) and write-back (phase 5).
Not verified: real Serato-tagged files. The decoder is tested against data built to the documented format. Q4's sample files would settle it.

