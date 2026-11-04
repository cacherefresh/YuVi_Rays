# Debugging "MIDI doesn't work": reading the controller's real mapping

*Written by Claude, 2026-11-03.*

Rob reported that MIDI did nothing, even though the MPK Mini Mk II was connected and showed in Chrome. The cause was wrong numbers in the profile. This note covers how the real numbers were found without pressing anything, the fixes, and how to rerun the tests.

Earlier steps (USB, accessory security, the two debuggers) are in [debugging_local_server_and_midi.md](debugging_local_server_and_midi.md).

---

## Root cause

| Control | Old profile expected | The controller actually sends |
|---|---|---|
| Knobs K1–K8 | CC 70–73 (MPK Mini **mk3** factory numbers) | **CC 1–8**, channel 1 |
| Pads 1–8, bank A | Notes 36–43 on channel 10 | **Notes 44–51 on channel 1** |

No message matched a binding, so nothing happened. The settings dialog's "Last MIDI message" line would have shown the real numbers once a control was moved.

---

## 1. Check Chrome sees the controller and has permission

```
PAGE=<app page WebSocket from: curl -s http://127.0.0.1:<chrome-port>/json/list>
dart run tool/ws_rpc.dart $PAGE '{"id":1,"method":"Runtime.evaluate","params":{"expression":"navigator.permissions.query({name:\"midi\"}).then(p=>p.state)","awaitPromise":true,"returnByValue":true}}'
```

Result: `granted`, the MIDI setting was `"true"`, and the input list was `MPK Mini Mk II | connected`.

**Gotcha:** a port's `connection` stays `closed` if you attach a listener with `addEventListener`. Either set `onmidimessage` or call `input.open()`. Each `requestMIDIAccess()` call gets its own port objects, so the app's open ports don't open yours.

## 2. Read the controller's settings over SysEx (no button presses needed)

The MPK Mini Mk II returns its whole configuration when asked. This needs SysEx permission, which Chrome's debugger **did** grant here, unlike plain MIDI the day before:

```
B=<browser WebSocket from: curl -s http://127.0.0.1:<chrome-port>/json/version>
dart run tool/ws_rpc.dart $B '{"id":1,"method":"Browser.setPermission","params":{"origin":"http://localhost:8090","permission":{"name":"midi","sysex":true},"setting":"granted"}}'
```

Then ask for programs 0 to 4. Program 0 is the settings in use right now:

```
EXPR='navigator.requestMIDIAccess({sysex:true}).then(async a => { const inp=[...a.inputs.values()][0], out=[...a.outputs.values()][0]; const got=[]; inp.onmidimessage=e=>{ if (e.data[0]===0xF0) got.push(Array.from(e.data)); }; await inp.open(); await out.open(); for (const p of [0,1,2,3,4]) { out.send([0xF0,0x47,0x00,0x26,0x66,0x00,0x01,p,0xF7]); await new Promise(r=>setTimeout(r,400)); } return got.map(b=>b.map(x=>x.toString(16).padStart(2,\"0\")).join(\" \")); })'
dart run tool/ws_rpc.dart $PAGE "{\"id\":1,\"method\":\"Runtime.evaluate\",\"params\":{\"expression\":\"$EXPR\",\"awaitPromise\":true,\"returnByValue\":true}}"
```

| Bytes | Meaning |
|---|---|
| `F0 47 00 26 66 00 01 <p> F7` | Request: Akai (`47`), MPK Mini Mk II (`26`), get program (`66`), program `p` |
| `F0 47 00 26 67 00 6D <109 bytes> F7` | Reply (`67`) with 109 (`6D`) data bytes |

Decoding the 109 bytes of program 0:

| Offset | Value | Meaning |
|---|---|---|
| 0 | `00` | Program 0 (current) |
| 1 | `00` | Pad channel, 0-based: **channel 1** |
| 2 | `00` | Key channel: channel 1 |
| 20–83 | 16 × (note, PC, CC, mode) | Pads. Bank A notes **44–51**, bank B 32–39 |
| 84–107 | 8 × (CC, min, max) | Knobs: **CC 1–8**, range 0–127 |
| 108 | `0C` | Transpose 0 |

The raw dump is saved as `test/fixtures/mpk_mini_mk2/program_dump.txt`. The decoder is `test/support/mpk_mini_mk2_sysex.dart`. Programs 2–4 use channel 10 and other notes, so if Rob switches the controller's PROG, the profile won't match.

**Still unconfirmed:** the per-pad "mode" byte is `1` on every pad. It is believed to mean *momentary* (note-off on release). If it meant *toggle*, a pad would only send note-off on the second hit, and the hold gesture would misfire. One real press with `tool/capture_midi_session.sh` running settles it.

## 3. Fixes made

- `assets/midi_profiles/akai_mpk_mini_mk2.yaml` now uses the real numbers and plan 003's layout.
- Profiles are now YAML with comments. JSON still loads, because JSON is valid YAML.
- The song list didn't load, for three reasons, all fixed:
  1. `manifest.json` listed plain file names, and the app only accepted `{name, file}` objects. It now accepts both.
  2. Only `manifest.json` was bundled, not the MP3s. `pubspec.yaml` now bundles the whole `assets/royalty_free_audio/` folder.
  3. **Unicode:** macOS stored the file name *decomposed* (`n` + combining tilde, bytes `6E CC 83`). The manifest had the *composed* `ñ` (`C3 B1`). They look the same but don't match. The app now compares both NFC-normalized (`lib/util/unicode_nfc.dart`).
- The URL for bundled files now comes from `ui_web.assetManager.getAssetUrl`, which gives `assets/assets/...` and URL-encodes the name.

How the Unicode problem was found, by listing what Flutter actually bundled:

```
curl -s http://localhost:8090/assets/AssetManifest.bin.json | python3 -c "import sys,json,base64,re; b=base64.b64decode(json.load(sys.stdin)); print(sorted(set(re.findall(rb'assets/[\x20-\x7e\x80-\xff]+?\.(?:mp3|json|yaml)', b))))"
```

It printed `Espan\xcc\x83ol`, not `Espa\xc3\xb1ol`.

---

## 4. Tests

### In CI: the fake MIDI runner (no browser, no hardware)

```
flutter test test/midi_fake_runner_test.dart
```

`test/support/fake_midi_runner.dart` replays a session file through the **real** profile, `MidiMapper` and `CommandDispatcher`. Only the mixer is fake (`test/support/fake_mixer.dart`), and time is simulated. It checks:
- **Profile vs the controller.** The profile's numbers match the controller's own SysEx dump, so any drift fails the build.
- **Pads.** Pad 1 plays and pauses. Pad 2 held sets the cue where the press began. Pad 2 tapped plays from the cue.
- **Pitch knobs.** K2 and K3 set coarse and fine pitch in percent, and pick-up ignores a pitch knob until it crosses the current value.

Proven to catch the original bug: changing K2 back to CC 70 failed 3 tests.

`.github/workflows/flutter-ghpages-testbuild.yaml` runs `flutter test` for the app and every package with a `test/` folder on each PR to `sanctuary`, before the build.

### Locally: the live smoke test (real audio engine)

```
flutter run -d chrome --target lib/web_main.dart --web-port 8090
tool/live_midi_smoke.sh
```

It injects fake MIDI through `window.yuviDebugInjectMidi`. The hook exists in **debug builds only** (`lib/input/debug_midi_hook.dart`). The script loads the first manifest song into Deck A and checks it plays, reaches the meter, the knobs set the speed, the playhead follows the speed, pad 2 holds and taps work, and pad 1 pauses. On 2026-11-03 every step passed.

The script marks its debugger call as a user gesture (`"userGesture": true`), so Chrome's autoplay rule doesn't block the audio.

### Recording a real session for the test

```
tool/capture_midi_session.sh 20 test/fixtures/mpk_mini_mk2/session_real.yaml
```

Press pads and turn knobs during the 20 seconds. The file has the same format as the synthesized one, so it can be replayed in a test. Keep recordings under about 55 seconds, because `tool/ws_rpc.dart` waits at most 60 seconds for a reply.
