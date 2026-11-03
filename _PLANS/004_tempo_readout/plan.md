# Plan 004 — Tempo readout above the pitch fader

**Status:** Done 2026-11-03. Option A: BPM. Verified live: 150.00 BPM detected, 155.72 at +3.81% pitch.
**Source:** Rob, 2026-11-03: "a 3 digit plus 2 decimal places number above the −16 to 16% pitch adjust, in the same font as the semitones, purple for both channels, 75% opacity."

---

## 1. What it looks like

A new line above the existing pitch label row, on both decks:

```
  124.35                          ← new: purple, 75% opacity
  PITCH  +3.81%   +0.65 st   RST
  ├──────────────┼───────■───────┤
```

| Property | Value |
|---|---|
| Format | 3 digits, a point, 2 decimals: `124.35`. Values under 100 are zero-padded, `098.20`, so the width never changes. |
| Font | Same as the semitone readout: monospace, size 10 |
| Colour | Purple `#B388FF` at 75% opacity, the same on both decks, not the deck's accent colour |
| Before a track loads | `---.--` |

The font is monospace, so the digits don't shift sideways as the value changes.

## 2. Which number? (Q1)

| Option | Example | What it shows | Effort |
|---|---|---|---|
| **A. Tempo in BPM** (likely meaning) | `124.35` | The track's tempo × the current speed, so you can match two decks by eye | **Larger:** the app doesn't know any track's BPM yet, so it needs detection (section 3) |
| **B. Speed as a percentage** | `103.81` | 100 + the pitch percent | **Small:** display only, no new data |

## 3. If A: where the track's BPM comes from

Shown BPM = detected BPM × playback rate. For example 120.00 × 1.0381 = 124.57.

| Source | Pros | Cons |
|---|---|---|
| **`web-audio-beat-detector`** (npm library, MIT) | Existing, maintained library, in line with AGENTS.MD's "use libraries that exist". Works on the decoded audio the deck already has. Runs off the main thread. | One more script from a CDN. Can land on half or double the true tempo on some tracks. |
| ID3 `TBPM` tag in the MP3 | Exact when present. Serato and Rekordbox write it. | Many files don't have it. Needs the ID3 reader from plan 002. |
| Tap tempo button | Always works | Manual |
| Write our own detector | No dependency | More code to maintain, likely worse results |

**Recommended for A:**
1. Detect with `web-audio-beat-detector` when a track loads, inside `yuvi_bridge.js`, and send `{bpm}` to Dart.
2. Store it as `DeckState.baseBpm`, and compute the shown BPM as `baseBpm × playbackRate`.
3. Later, when plan 002 adds ID3 reading, prefer the file's `TBPM` tag over detection.

While detection runs (about 1 to 2 seconds) the readout shows `---.--`.

## 4. Where the code goes

| Layer | Change |
|---|---|
| `yuvi_controls` | `PitchFaderWidget` gets an optional `tempo` value and renders the purple line. No audio knowledge: it only formats a number. |
| `yuvi_audio_engine` | Option A only: `DeckState.baseBpm`, plus a `bpm` event from the bridge |
| `web/js/yuvi_bridge.js` and `web/index.html` | Option A only: load the library and detect on load |
| Tests | Unit-test the `000.00` formatting and the BPM × rate maths |

## 5. Decisions (Rob, 2026-11-03)

| Question | Answer |
|---|---|
| Which number | **A: BPM = detected BPM × pitch adjustment** |
| Detector | **`web-audio-beat-detector`**, run when a track loads |
| Tag vs detection | **New setting "Prefer BPM from the MP3 tag", default off.** When it's off, the detected BPM wins. Each source falls back to the other when missing. |
| Future | A separate feature for a metadata cache file covering all tracks, so they load faster next time without writing to the MP3. Logged as FR-008. |

## 6. Build notes

- **Loading the library.** Version 8.2.31's browser build needs a chain of helper scripts as globals. jsDelivr's self-contained module build (`/+esm`) is loaded with `import()` from `yuvi_bridge.js` instead. It's pinned to 8.2.31, released 2025-09-29, and preloaded at start-up because the first CDN load took about 2 s.
- **Measured on Rob's song:** 150.00 BPM, with `analyze()` taking about 0.36 s on a 218 s track.
- **Tempo range.** The detector searches 90–180 BPM by default, so a slow song can come out at double its tempo. A future option could set the range.
- **The tag reader** is a new pure-Dart package, `yuvi_track_metadata`, holding the ID3v2 reader that plan 002 will extend for Serato cues. It reads `TBPM` from ID3v2.2, v2.3 and v2.4.
- **Rob's test song is MP4/AAC** (`ftyp mp41`) with an `.mp3` name. MP4 files have no ID3 tag, so the tag setting falls back to detection for it.
- **Loading paths.** Both local files and preset tracks now load as bytes, so the tag can be read in one place, `DeckAudioController.loadBytes`.
