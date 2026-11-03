# Plan 001 — MIDI controller, keyboard shortcuts, master & headphone bus

**Status:** In progress. Phases 1–3 are built (2026-11-02) and pass unit tests and the web build. They have not been tried in a browser or on hardware yet. Phase 4 (MIDI learn) is next.
**Branch:** `feature/midi_hardware_plus_crossfader_via_audio`
**Source requests:** `_DEVELOPER_NOTES/_NON_HUMAN_NOTES/feature_requests_and_findings.md` FR-001, FR-002, FR-003

---

## 1. Goal

Let a DJ drive both decks from (a) the computer keyboard and (b) an Akai
MIDI controller, in Chrome on the GitHub Pages build, without the input
code knowing anything about Tone.js or widgets.

Out of scope for this plan: true separate headphone output, MIDI output
(pad LEDs), jog wheels, more than 4 faders.

---

## 2. Key design decision — one command contract for all inputs

Today the only input is the on-screen UI, which calls `DeckAudioController`
directly. Adding keyboard and MIDI the same way would put three copies of
"what does play/pause mean" in three places.

Instead, every input source emits a small, typed **command**. One
dispatcher applies commands to the mixer. Input sources never touch audio.

```
 Keyboard ─┐
 MIDI     ─┼─▶  MixerCommand  ──▶  CommandDispatcher ──▶ MixerProvider ──▶ DeckAudioController ──▶ yuvi_bridge.js (Tone.js)
 UI (later)┘     (contract)          (app layer)
```

### Contract (new package `packages/yuvi_input`)

```dart
sealed class MixerCommand {}

// Deck transport — deckId is a String so 3–4 decks work later.
class TogglePlay   extends MixerCommand { final String deckId; }
class JumpToCue    extends MixerCommand { final String deckId; }
class SetCue       extends MixerCommand { final String deckId; }
class Stop         extends MixerCommand { final String deckId; }

// Continuous controls — value is always normalized 0.0..1.0.
class SetChannelVolume   extends MixerCommand { final String deckId; final double value; }
class SetMasterVolume    extends MixerCommand { final double value; }
class SetHeadphoneVolume extends MixerCommand { final double value; }
class SetCrossfader      extends MixerCommand { final double value; }

abstract interface class InputSource {
  Stream<MixerCommand> get commands;
  Future<void> start();
  Future<void> stop();
}
```

`yuvi_input` depends only on `flutter` and `package:web`. It does **not**
depend on `yuvi_audio_engine`. That keeps it reusable in any other Flutter
web music app.

### Mappings are data, not code

```json
// assets/midi_profiles/akai_default.json
{
  "name": "Akai default (8 pads, 4 knobs)",
  "controls": [
    { "type": "cc",   "channel": 0, "number": 70, "command": "SetMasterVolume" },
    { "type": "cc",   "channel": 0, "number": 71, "command": "SetChannelVolume", "deck": "A" },
    { "type": "cc",   "channel": 0, "number": 72, "command": "SetChannelVolume", "deck": "B" },
    { "type": "cc",   "channel": 0, "number": 73, "command": "SetHeadphoneVolume" },
    { "type": "note", "channel": 9, "number": 36, "command": "TogglePlay", "deck": "A" }
  ]
}
```
CC/note numbers above are placeholders until the exact model is known
(see Q1). Phase 4 adds "MIDI learn" so numbers never need editing by hand.

---

## 3. Audio graph changes (yuvi_bridge.js)

There is no master gain node today. Each deck goes straight to
`Tone.Destination`, and the crossfader is multiplied into the deck volume
in Dart. New graph:

```
Player → EQ3 → ChannelVol ─→ XfadeGain ─┐
Player → EQ3 → ChannelVol ─→ XfadeGain ─┴─▶ MasterBus ─▶ MasterVol ─┬─▶ Meter
                                                                    └─▶ HeadphoneVol ─▶ Destination
```

- **ChannelVol** — fader 2 / fader 3 and the on-screen faders.
- **XfadeGain** — crossfader, now a real node (FR-003). Removes the
  `_crossGain` bookkeeping from `DeckAudioController`.
- **MasterVol** — fader 1. The VU meter taps **after** it, like a Pioneer mixer.
- **HeadphoneVol** — fader 4. In v1 it sits in series with master because a
  laptop has one stereo output. Final level = master × headphone.
  This is the one place that changes when split cue (option b) or a second
  output device (option c) is added — nothing upstream moves.

New bridge functions: `setMasterVolume(v)`, `setHeadphoneVolume(v)`,
`setCrossfader(v)`. Same dB curve as the existing `setVolume`.

> Question for Rob (Q3): with only one output, should fader 4 be in series
> (as above, turning it down silences everything) or should it do nothing
> audible until split cue exists? Series is the default here.

---

## 4. Phases

Each phase is one PR into `sanctuary` (which auto-deploys), and leaves the
app working.

### Phase 1 — Master bus + crossfader in the graph
- `yuvi_bridge.js`: add XfadeGain per deck, shared MasterVol and HeadphoneVol, move meter tap.
- `js_bridge.dart` + new `MixerAudioController` in `yuvi_audio_engine` for master-level controls.
- `MixerProvider`: crossfader calls the bridge; remove `_crossGain` from `DeckAudioController`.
- UI: a small vertical master fader beside the VU meter; headphone knob next to it.
- Update the audio-graph widget to show the new nodes.

### Phase 2 — Command contract + keyboard
- Create `packages/yuvi_input` with `MixerCommand`, `InputSource`, `KeyboardInputSource`.
- Keyboard binds by **physical key** (`PhysicalKeyboardKey`), so `[` and `{` are the same key and non-US layouts keep the column shape.

| Deck A | Deck B | Action |
|---|---|---|
| `[` | `]` | Play / pause |
| `;` | `'` | Jump to cue |
| Shift + `;` | Shift + `'` | Set cue |
| `.` | `/` | Stop |

- Shortcuts are ignored while a text field has focus.
- `CommandDispatcher` in the app layer (`lib/input/`) maps commands to `MixerProvider`.
- Unit tests: key event → command; command → provider call.

### Phase 3 — MIDI (opt-in)
- Settings: a gear icon in the app bar opens a small panel with an **Enable MIDI controller** switch.
- Switching it ON calls `navigator.requestMIDIAccess()`, which makes Chrome show its permission prompt. The choice is saved in `localStorage` so it survives reloads.
- On reload with the setting ON, MIDI is requested again. Chrome won't re-prompt once granted.
- `MidiInputSource` (in `yuvi_input`, via `package:web`, no extra JS file) listens to all inputs, handles hot-plug (`onstatechange`), and translates messages through the JSON profile.
- Show the connection state in the settings panel: "Not supported in this browser", "Permission denied", "No device", "Connected: <device name>".
- Pads use note-on and ignore velocity for transport actions.

### Phase 4 — MIDI learn (small, but it removes guesswork)
- In settings, click a mixer control, move a knob or hit a pad, and the binding saves to `localStorage`.
- "Reset to default profile" button.

### Phase 5 (later, separate plan) — real headphone cue
- Per-deck cue (PFL) buttons, then split-cue mode, then optional second output via `setSinkId`.

---

## 5. Files touched

| Area | File |
|---|---|
| Audio graph | `web/js/yuvi_bridge.js` |
| Bridge contract | `packages/yuvi_audio_engine/lib/src/js_bridge.dart` |
| Engine | `packages/yuvi_audio_engine/lib/src/deck_audio_controller.dart`, new `mixer_audio_controller.dart` |
| New package | `packages/yuvi_input/` |
| App wiring | `lib/providers/mixer_provider.dart`, new `lib/input/command_dispatcher.dart`, new `lib/settings/` |
| UI | `lib/screens/mixer_screen.dart`, `packages/yuvi_controls/lib/src/audio_graph_widget.dart` |
| Data | `assets/midi_profiles/akai_default.json`, `pubspec.yaml` assets |

---

## 6. Risks

- **Browser support.** Web MIDI works in Chrome and Edge. Safari has none. Show a clear message and never crash.
- **Focus.** Flutter web keyboard events need a focused widget. Use a root `Focus`/`Shortcuts` that reclaims focus after dialogs close.
- **Chrome reserved keys.** None of the six chosen keys are reserved by Chrome. `/` is quick-find in Firefox only.
- **Fader jump.** Physical knobs don't match the on-screen value at connect time. v1 jumps to the knob's value. "Soft takeover" can come later.
- **Auto-deploy.** Every merge to `sanctuary` goes live. Run the `verify-web-build` skill before each PR.

---

## 7. Open questions for Rob

1. **Which exact Akai model?** For example LPD8, MPK Mini mk3, or MPD218. This sets the default CC and note numbers. With MIDI learn in Phase 4 this matters less.
2. **Pads.** The 8 pads aren't assigned yet. Proposed: pads 1–4 = Deck A play, cue, stop, set cue. Pads 5–8 = the same for Deck B.
3. **Headphone fader with one output.** In series with master (proposed), or inactive until split cue exists?
4. **Cue key behaviour.** Proposed: key = jump to cue, Shift + key = set cue. The alternative is CDJ-style: one press sets the cue when paused and returns to it when playing.
5. **Your message ended with "i also want…".** What was the rest?

---

## 8. Build log

**2026-11-02. Phases 1–3 built, using the proposed answers to Q2–Q4.**

| Area | Where |
|---|---|
| Master, headphone and crossfader nodes | `web/js/yuvi_bridge.js` |
| Master state, controller, crossfader curve | `packages/yuvi_audio_engine/lib/src/` |
| Command contract, keyboard, MIDI | `packages/yuvi_input/` (new) |
| Dispatcher and input wiring | `lib/input/` |
| MIDI on/off setting and dialog | `lib/settings/` |
| Device profiles | `assets/midi_profiles/*.json` |

Differences from the plan:
- The keyboard listens through a global `HardwareKeyboard` handler instead of a root `Focus` widget. Shortcuts work wherever focus is, so nothing needs to reclaim focus.
- Fader changes ramp over 20 ms to avoid zipper noise from 7-bit MIDI steps.
- The settings dialog includes a MIDI monitor that shows the last message received. That is the stop-gap until MIDI learn.
- Profiles are picked by matching the device name. The profile with no device names is the fallback.

Still to verify by hand: Chrome's permission prompt, a real Akai device, and the keyboard keys in the deployed build.
