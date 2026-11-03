# Plan 003 — MPK Mini Mk II layout, pitch knobs, hold-to-set-cue pad, and user MIDI config

**Status:** Done 2026-11-03, all phases. Phase 5 (Settings MIDI mapping) was added with plan 002's controller work.
**Builds on:** Plan 001 (command contract, MIDI profiles, settings).
**Source:** Rob's request, 2026-11-03. Logged in `_DEVELOPER_NOTES/_NON_HUMAN_NOTES/feature_requests_and_findings.md` as FR-006.

---

## 1. Requested layout

The MPK Mini Mk II has two rows of 4 knobs. K1–K4 are the top row and K5–K8 the bottom row. Each column pairs Deck A on top with Deck B below:

```
        col 1          col 2                 col 3                 col 4
top     K1 A volume    K2 A pitch (coarse)   K3 A pitch (fine)     K4 master
bottom  K5 B volume    K6 B pitch (coarse)   K7 B pitch (fine)     K8 headphones

Pads (bank A), bottom row:
        pad 1 A play/pause   pad 2 A cue   pad 3 B play/pause   pad 4 B cue
```

| Control | Deck | Action |
|---|---|---|
| K1 | A | Channel volume |
| K5 | B | Channel volume |
| K2 | A | Pitch, coarse: −16% to +16% |
| K6 | B | Pitch, coarse: −16% to +16% |
| K3 | A | Pitch, fine: an extra −1% to +1% |
| K7 | B | Pitch, fine: an extra −1% to +1% |
| K4 | | Master volume |
| K8 | | Headphones volume |
| Pad 1 | A | Play / pause. A second hit pauses where it is. |
| Pad 2 | A | **Tap** (released within 1 s): play from cue. **Hold** 1 s or more: set the cue where the press began. |
| Pad 3 | B | Play / pause |
| Pad 4 | B | Same as pad 2, for Deck B |

Final speed = 1 + (coarse + fine) / 100. Example: coarse +4%, fine −0.3%, so speed is 1.037.

---

## 2. How the knobs will work

The Mk II's knobs are ordinary turn-limited knobs, not endless encoders. Each sends a value from 0 to 127 for its position.

- **Volume knobs:** 0 is silent and 127 is full. They use the same loudness curve as the on-screen fader.
- **Pitch knobs:** the centre value, 64, is exactly 0%. Below 64 scales to −16% (or −1%), and above 64 to +16% (or +1%). Mapping around 64 instead of evenly across 0–127 is what makes the centre land exactly on 0%. Knobs have no centre click, so the screen shows the value while you turn.
- **Range lives in the profile,** not in code. A pitch binding carries its own `min` and `max`, so a different controller can use ±8% or ±50% by editing data.

### Knob position vs the on-screen value

When the app starts, or you move the on-screen fader, the physical knob no longer matches the screen. There are two ways to handle the next knob turn:

| Mode | What happens | Good for |
|---|---|---|
| **Jump** | The value snaps straight to the knob's position. | Volume, which is easy to correct by ear |
| **Pick-up** (soft takeover) | The knob has no effect until it passes the current on-screen value. Then it takes over smoothly. | Pitch, where a sudden jump of up to 16% would be very audible mid-mix |

**Proposed:** jump for volume, pick-up for pitch. It's a per-binding setting in the profile (`takeover: jump | pickup`).

### The on-screen pitch fader

The on-screen pitch fader currently works in **semitones (±7)** and shows a percent readout. The plan changes the fader's range to **±16%**, to match the coarse knob, and **displays both units** (Rob, 2026-11-03):

```
PITCH  +4.37%   +0.74 st
```

- **Percent** is the speed change: coarse + fine.
- **Semitones** is how far the key moves at that speed: 12 × log2(speed). There is no key lock, so changing speed always changes the key. +16% is about +2.57 semitones, and −16% is about −3.02.
- The fader moves coarse pitch. Both readouts show the total, including fine.
- The same readout goes in the audio graph's deck node.

### Existing bug this plan must fix

`web/js/yuvi_bridge.js` works out the playhead position as *time elapsed since play*, ignoring speed. With pitch at +16%, the playhead, the cue point and end-of-track detection all drift by 16%. The fix is to track position as elapsed time × speed, and re-anchor whenever the speed changes.

---

## 3. Pad 2: tap vs hold

```
press ──┬── released before 1.0 s ──▶ TAP:  jump to cue and play
        └── still held at 1.0 s   ──▶ HOLD: set cue at the position where the press began
```

- **The cue position is captured at the moment of the press,** not after the second has passed. So a cue set while the track plays lands where you pressed, not a second later.
- **Trade-off:** a tap can only be recognised on **release**, because until then it might become a hold. So play-from-cue starts when you let go, not when you hit. For a quick tap that's roughly 50–150 ms later than a normal button. If that's too slow for cue drops, see the alternative in Q5.

### Contract changes (`yuvi_input`)

Gestures are data in the profile, so any pad on any controller can be given tap/hold behaviour:

```yaml
- note: 37
  deck: A
  on_press: armCue        # remember the current position
  on_tap: playFromCue     # released before hold_ms
  on_hold: commitCue      # still held at hold_ms: the remembered position becomes the cue
  hold_ms: 1000
```

New commands: `PlayFromCue`, `ArmCue`, `CommitArmedCue`, `SetPitchCoarse(deck, percent)`, `SetPitchFine(deck, percent)`. A small gesture tracker in `yuvi_input` turns press and release events into these, with an injectable clock so it can be unit tested without real time passing.

---

## 4. Where MIDI settings live today, and the proposal

### Today

| What | Where | Format | Who can change it |
|---|---|---|---|
| Device profiles | `assets/midi_profiles/*.json`, built into the app | JSON | Developers, by editing the file and rebuilding |
| Which profile a device gets | Automatic: the device's name is matched against each profile's `deviceNameContains` | | Nobody at runtime |
| MIDI on/off | Browser `localStorage`, key `yuvi.settings.midiEnabled` | `"true"` or `"false"` | The user, in Settings |

There is **no way for a user to override a mapping yet**. That's the gap for generic devices.

### Proposal: three layers, highest wins

```
1. User mapping (browser localStorage, per device)    ← set in the app, survives reloads
2. Bundled profile matched by device name             ← assets/midi_profiles/, in git
3. Generic fallback profile                           ← for any unknown device
```

A **"MIDI mapping" section in Settings**, for each connected device:
- **Profile:** a drop-down of the bundled profiles plus "Custom". Plugging in an unknown controller and choosing "Generic" or "Akai MPK Mini" is a single click.
- **Export:** downloads the mapping in use as a file. That gives anyone with a generic controller a starting template.
- **Import:** loads an edited file, validates it, and stores it as that device's custom mapping. Errors name the line and the problem.
- **Reset:** forgets the custom mapping and goes back to the bundled profile.
- Later, **MIDI learn** (plan 001 phase 4) writes into the same custom mapping.

Custom mappings are stored per device name, so an MPK and a DJM-S9 used together each keep their own.

### Format: YAML or JSON (Q1)

| | YAML | JSON |
|---|---|---|
| Comments | **Yes.** `# K1 = Deck A volume` can sit next to each line. | No. Today's files fake it with a `_comment` field. |
| Hand editing | Easier, less punctuation | Strict commas and quotes |
| Runtime cost | Adds `package:yaml`, a small pure-Dart package maintained by the Dart team. Works on web. | Built in |
| Errors | Line and column numbers | Line and column numbers |

**Recommendation: YAML** for the bundled profiles and for import and export, because profiles are meant to be edited by hand and comments matter. Internally it is parsed into the same `MidiProfile` model, and the browser copy can be stored as JSON. The model doesn't care which format the text came from.

Example of the MPK Mini Mk II profile in YAML:

```yaml
name: Akai MPK Mini Mk II
device_name_contains: [MPK Mini Mk II, MPK mini]
verified: false        # true once checked with the Settings MIDI monitor

knobs:                 # CC numbers are the Mk II factory defaults: CHECK on hardware
  - { cc: 1, action: channelVolume, deck: A }                                       # K1
  - { cc: 5, action: channelVolume, deck: B }                                       # K5
  - { cc: 2, action: pitchCoarse, deck: A, min: -16, max: 16, takeover: pickup }    # K2
  - { cc: 6, action: pitchCoarse, deck: B, min: -16, max: 16, takeover: pickup }    # K6
  - { cc: 3, action: pitchFine,   deck: A, min: -1,  max: 1,  takeover: pickup }    # K3
  - { cc: 7, action: pitchFine,   deck: B, min: -1,  max: 1,  takeover: pickup }    # K7
  - { cc: 4, action: masterVolume }                                                 # K4
  - { cc: 8, action: headphoneVolume }                                              # K8

pads:                  # bank A, channel 10
  - { note: 36, channel: 10, deck: A, on_press: togglePlay }                        # pad 1
  - { note: 37, channel: 10, deck: A, on_press: armCue, on_tap: playFromCue,
      on_hold: commitCue, hold_ms: 1000 }                                           # pad 2
  - { note: 38, channel: 10, deck: B, on_press: togglePlay }                        # pad 3
  - { note: 39, channel: 10, deck: B, on_press: armCue, on_tap: playFromCue,
      on_hold: commitCue, hold_ms: 1000 }                                           # pad 4
```

Plan 001's guess of CC 70–73 is for the MPK Mini **mk3**. The **Mk II** factory setting is believed to be CC 1–8 for K1–K8, but this must be checked with the Settings MIDI monitor before the profile is marked `verified: true`.

---

## 5. Phases

1. **Check the hardware.** Read the real CC and note numbers for K1–K8 and pads 1–8 from the Settings MIDI monitor, and record them in the profile.
2. **Engine:** percent-based pitch (coarse + fine), the speed-aware playhead fix, set cue at a given position, play from cue. Unit tests for the pitch maths.
3. **Input contract:** binding `min`/`max`/`takeover`, pad gestures with a testable gesture tracker, the new commands, and the YAML loader. Unit tests for the centre-64 mapping, pick-up, and tap vs hold timing.
4. **Profiles:** convert the bundled profiles to YAML and add the Mk II layout.
5. **Settings:** the MIDI mapping section with profile choice, import, export and reset, with custom mappings stored in localStorage.
6. **Docs:** update `DJ_SETUP_INSTRUCTIONS.md` with the new layout diagram.

---

## 6. Decisions

| # | Question | Answer (Rob, 2026-11-03) |
|---|---|---|
| Q1 | Profile format | **YAML** |
| Q2 | Deck B pads | **Pads 3 and 4**, same row as Deck A |
| Q3 | K4 and K8 | **K4 master volume, K8 headphones** |
| Q4 | Pad 1 second hit | **Pause**, staying where it is |
| — | On-screen pitch units | **Show both** percent and semitones |
| Q5 | Pad 2 timing | Open. Building as requested: play from cue on release. The faster alternative is in section 3. |

Still needed from Rob before phase 2: the real CC and note numbers from the Settings MIDI monitor (phase 1).

---

## 7. Build log

**2026-11-03. Phases 1–4 and 6 built. Phase 5 still to do.**

| Phase | Result |
|---|---|
| 1. Hardware check | Done without pressing anything: the controller's SysEx program dump gave knobs CC 1–8 and pads 44–51 on channel 1. See `_DEVELOPER_NOTES/_NON_HUMAN_NOTES/debugging_midi_mapping.md`. |
| 2. Engine | Percent pitch (coarse + fine), the playhead drift fix, cue at a given position, play from cue. `DeckControls` and `MixerControls` contracts in `yuvi_audio_engine/mixer_contracts.dart`. |
| 3. Input contract | YAML profiles, `MidiMapper` with tap and hold, `SoftTakeover`, new commands. `yuvi_input.dart` is pure Dart; `yuvi_input_web.dart` adds Web MIDI. |
| 4. Profiles | `akai_mpk_mini_mk2.yaml` (real numbers), `generic.yaml`, `akai_mpd226.yaml`, `pioneer_djm_s9.yaml` |
| 5. Settings mapping UI | **Done.** `MidiProfileRegistry` (user choice, then name match, then generic, stored per device in localStorage), `MidiProfile.toYaml()` for Export, and validated Import. Section in `lib/settings/midi_mapping_section.dart`. |
| 6. Docs | `DJ_SETUP_INSTRUCTIONS.md` section 3 |

Also added:
- **The fake MIDI test runner** (`test/midi_fake_runner_test.dart`). It runs in the PR workflow.
- **A live smoke test** (`tool/live_midi_smoke.sh`), passing against the real audio engine.
- **A session capture script** (`tool/capture_midi_session.sh`).
- **The song-list fixes:** the manifest format, MP3 bundling, Unicode file names and the asset URL.

Differences from the plan:
- Pick-up lives in the dispatcher, because only the app knows the current value. Commands carry a `pickupTolerance` (3% of the knob's range) instead of a flag.
- Pads can be note or CC based, so DJ mixers with CC buttons fit the same format.

