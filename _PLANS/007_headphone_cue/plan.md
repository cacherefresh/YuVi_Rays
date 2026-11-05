# Plan 007 — Headphone cue on a second output device

**Status:** In progress (Rob approved 2026-11-04). Built; waiting for Rob's test on a real second device.
**Branch name when started:** `feature/headphone-cue`
**Covers:** Rob's "Speakers + Headphones with Deck Cueing" guide (2026-11-04), and the "Headphones on a laptop" note in DJ_SETUP_INSTRUCTIONS.md.

---

## 1. Rob's decisions (2026-11-04)

| Question | Decision |
|---|---|
| Where the headphone cue plays | **Any second output device** the browser can see: a USB audio interface, USB or Bluetooth headphones, an HDMI display. |
| Where the cue taps each deck | **Before the fader** (PFL): after the EQ, before the channel fader and crossfader. As on Pioneer mixers and in Mixxx. |
| Headphone controls | **A cue on/off button per deck**, plus a **cue/master mix knob** and a **headphone level knob** in the master section. No per-deck cue level. |

## 2. Where this plan differs from the guide, and why

1. **The MacBook headphone jack is not a second output.** In macOS the built-in speakers and the 3.5 mm jack are one device; plugging in headphones mutes the speakers. `setSinkId` can't split them. A second device is needed (decision above).
2. **Pre-fader tap, not post-fader.** A post-fader tap goes silent when the fader is down, which is exactly when you want to cue the next track.
3. **No per-deck cue level.** One on/off per deck, plus the mix and level knobs, matches real mixers and keeps the UI small.
4. **The headphone path is not sample-locked to the speakers.** The guide's method (one AudioContext → `MediaStreamDestination` → hidden `<audio>` → `setSinkId`) is still the right one: it keeps one audio graph and one clock for all processing. But the stream and the audio element add buffering, roughly 20–100 ms, and the second device runs on its own clock. So the headphones lag the speakers slightly, and a long session can drift or glitch briefly. That's fine for cueing. Bluetooth adds far more delay (150–300 ms) and makes beat matching by ear hard. Measure in phase 2.
5. **Seeing device names needs microphone permission in Chrome.** Chrome hides output device names and IDs until the site has a microphone grant. (`selectAudioOutput()`, the clean API for this, exists only in Firefox.) The device picker will ask for microphone access once, stop the microphone immediately, and say why on screen. Nothing is recorded.
6. **The current headphone knob changes meaning.** Today it sits after the master on the only output, so turning it down turns the speakers down. After this plan the speakers go straight from the master fader to the output, and the headphone knob affects only the headphones.
7. **No headphone device chosen means no headphone audio.** If the hidden `<audio>` element played without a chosen device, it would play on the default output: the same speakers, doubling the sound. So the cue path stays silent until a device is chosen.

## 3. Audio graph

Today:

```
Deck:   Player → EQ3 → Channel fader → Crossfader gain ─┐
Master: Master fader → Meter
                     → Headphone vol → Destination (the only output)
```

After:

```
Deck:   Player → EQ3 ─┬→ Channel fader → Crossfader gain ─→ Master fader ─┬→ Meter
                      │                                                   ├→ Destination (speakers)
                      │                                                   └→ Mix: master side ─┐
                      └→ Cue gate (0 or 1) ─→ Cue bus ─→ Mix: cue side ────────────────────────┤
                                                                                               ↓
                              Headphone level → MediaStreamDestination → hidden <audio>.setSinkId(device)
```

- **Cue gate:** a gain per deck, 0 when off and 1 when on, ramped over 20 ms like the other controls so it doesn't click.
- **Cue bus:** one gain node summing every cued deck.
- **Mix knob:** two gains with the existing `equalPowerCrossfade` curve. Full left is cue only, the centre is both, full right is master only.
- **Headphone level:** the existing `faderToDb` curve.
- **Everything stays in Tone.js's one AudioContext.** `Tone.getContext().rawContext.createMediaStreamDestination()` provides the stream.

## 4. Contracts (contract first)

**`DeckControls`** (yuvi_audio_engine, pure Dart):
- `bool get headphoneCue`
- `void setHeadphoneCue(bool on)`
- `void toggleHeadphoneCue()`

**`MixerControls`:**
- `double get headphoneMix`: 0 = cue, 0.5 = both, 1 = master
- `void setHeadphoneMix(double position)`
- `headphoneVolume` stays, with its new meaning (section 2, item 6).

**New `AudioOutputs` contract.** Choosing a device is setup, not mixing, so it stays out of `MixerControls`:
- `Future<List<AudioOutputDevice>> list()`: id and name. Asks for microphone permission when names are hidden.
- `Future<void> setHeadphoneDevice(String? id)`: null turns headphones off.
- `String? get headphoneDeviceId`
- `HeadphoneStatus get status`: off, connecting, playing, device lost, or not supported.
- A change notification, so the UI follows device plug and unplug events.

Implementation: `WebAudioOutputs` in yuvi_audio_engine calls new bridge functions. A fake goes in `test/support` for the app's tests.

**Bridge (`web/js/yuvi_bridge.js`), new functions:**
- `setHeadphoneCue(deckId, on)`
- `setHeadphoneMix(position)`
- `listOutputDevices()`
- `setHeadphoneSink(deviceId)`
- `onOutputDevicesChanged`: a `devicechange` listener that re-finds the chosen device by ID, or by name if the ID changed. Otherwise it reports "device lost".

## 5. UI

- **Deck:** a headphone button (headphone icon, lit when on). It's labelled "PFL" in tooltips, because "Cue" already means the cue point.
- **Master section:** a **MIX** knob (CUE ↔ MASTER) and a **PHONES** level knob, replacing today's phones knob.
- **Settings → Headphones:**
  - Output device dropdown, remembered in localStorage by device ID.
  - Status line.
  - A short note on Bluetooth delay.
  - A one-line explanation before the microphone permission request.
- **Audio graph widget:** add a CUE BUS node and a PHONES OUT node, and connect PHONES to the cue side.

## 6. Input

- **Commands:**
  - `ToggleHeadphoneCue(deck)`
  - `SetHeadphoneMix(value)`, a value command with pick-up support.
- **MIDI profile vocabulary:**
  - Pad action `headphoneCue`.
  - Knob action `headphoneMix`, centred, so the knob's centre is an exact 50/50 mix (like K8's crossfader).
- **Keyboard (assumption, change if you like):** **P** = Deck A headphone cue, **\\** = Deck B. They sit on the outer side of `[` and `]`.
- **MPK Mini Mk II:** no change. All 8 knobs and 16 pads are in use. Other profiles can map the new actions.

## 7. Phases

1. **Graph and contracts.**
   - Rewire the bridge (section 3).
   - Add the contract members, state and dispatcher cases.
   - Tests:
     - `DeckState` / `MasterState`: cue and mix values.
     - Dispatcher: the new commands.
     - The MIDI mapper: the new actions.
   - Check the live gains with the CDP smoke test.
   - Result: the speakers sound exactly as before. The headphone knob no longer turns the speakers down.
2. **Output device.**
   - `AudioOutputs` with the hidden `<audio>` element.
   - Settings dropdown, microphone permission note, remembered device, device change handling.
   - Manual test on Rob's machine with a second device. Measure the headphone delay against the speakers by ear, and note the result.
3. **UI.** Deck headphone button, MIX and PHONES knobs, audio graph nodes.
4. **Input.** Keyboard keys, MIDI actions, fake MIDI runner test for the new actions.
5. **Docs and verify.**
   - Update DJ_SETUP_INSTRUCTIONS.md: replace "Headphones on a laptop".
   - Add the new keys to the keyboard table in Settings.
   - Run `verify-web-build`.

## 8. Not in this plan

- **Split cue** (mono master in one ear, cue in the other, no extra hardware). It's easy to add later as a second headphone mode on the same cue bus.
- **One multi-channel device** (master on outputs 1-2, cue on 3-4). It avoids clock drift, but needs a 4-output interface to test with.
- **Per-deck cue level.** Rob chose not to have one.
- **Trim / gain knob per deck.** The app has none today. It's a separate idea.
- **Safari.** It has no `setSinkId`. The app targets Chrome; Safari shows "not supported".

## 9. Risks

- Bluetooth delay (section 2, item 4). Warn in Settings.
- Clock drift between the two devices may cause a brief glitch on long sessions. Watch for it in phase 2.
- Device IDs can change after a browser data clear. Fall back to matching by name.
- Chrome's autoplay rules: start the hidden element inside a click, such as the device dropdown or the first Play.

## 10. Build log (2026-11-04)

- Built on the current branch (`feature/midi_hardware_plus_crossfader_via_audio`), not a new `feature/headphone-cue` branch, because the branch already had uncommitted MIDI work.
- **Graph:** as in section 3. `masterVol → Destination` directly; per-deck `cueGate` taps `eq3`; `cueBus → mixCue`, `masterVol → mixMaster` → `phonesVol` → `MediaStreamDestination`.
- **Bridge:** `setHeadphoneCue`, `setHeadphoneMixGains`, `headphonesSupported`, `listOutputDevices(askPermission)`, `setHeadphoneSink(id, name)`, `getHeadphoneStatus`.
  - A blocked `play()` waits for the next click or key press (status `waitingForClick`).
  - A `devicechange` listener pauses on unplug (`lost`) and reconnects by ID or name.
- **Contracts:** `DeckControls.headphoneCue / setHeadphoneCue / toggleHeadphoneCue`, `MixerControls.headphoneMix / setHeadphoneMix`, new `AudioOutputs` (with `devicesVersion`), implemented by `WebAudioOutputs`.
- **Input:**
  - `ToggleHeadphoneCue`, `SetHeadphoneMix`.
  - MIDI pad action `headphoneCue`, knob action `headphoneMix` (centred).
  - Keys `P` and `\`.
- **UI:**
  - `HeadphoneCueButton` (yuvi_controls) under each deck fader.
  - MIX and PHONES knobs plus a status chip in the master section.
  - Settings → Headphones (lib/settings/headphone_section.dart).
  - Graph: SPEAKERS and PHONES nodes.
- **Remembered device:** `AppSettings.headphoneDeviceId / Name` in localStorage, reconnected at start-up.
- **Tests:**
  - yuvi_audio_engine/test/headphone_state_test.dart
  - keyboard and MIDI tests in yuvi_input
  - test/command_dispatcher_test.dart
- **Live check in Chrome over CDP** (port 8091), 12 of 12 passed. With deck A's fader at 0, PFL off gives a silent cue bus. After a real `P` key event, the cue bus reads −6.7 dB while the master stays silent (pre-fader confirmed).
- **Not verified yet:** audio actually reaching a second device (needs Rob's microphone grant and hardware), and the headphone delay against the speakers.
