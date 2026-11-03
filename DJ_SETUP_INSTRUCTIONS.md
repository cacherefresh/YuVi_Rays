# DJ Setup Instructions

How to connect hardware to YuVi Rays and what every control does.

YuVi Rays runs in the browser. Hardware control uses the **Web MIDI API**, which works in **Chrome and Edge** on desktop. Safari does not support it. Hardware only works on `https://` (the GitHub Pages site) or on `localhost` while developing.

---

## 1. Quick start

1. Plug the MIDI controller in over USB **before** opening the page. Hot-plugging later also works.
2. Open YuVi Rays in Chrome.
3. Click the **gear icon** at the top right. This opens Settings. On your first visit, a pop-up offers an **Open Settings** button that does the same.
4. Turn on **Enable MIDI controller**.
5. Chrome asks: *"Allow this site to control and reprogram your MIDI devices?"* Click **Allow**. Chrome remembers this, so you only see it once.
6. Settings now shows **Connected:** and your device name. Move a fader. The **Last MIDI message** line shows what the app received.

If you clicked **Block** by mistake, click the icon at the left of the address bar, open **Site settings**, set **MIDI devices** to **Allow**, and reload.

---

## 2. Computer keyboard

The keys for each deck run down the keyboard in a diagonal column. Keys work by physical position, so you don't need Shift. `[` and `{` are the same key.

| Action | Deck A (left) | Deck B (right) |
|---|---|---|
| Play / pause | `[` | `]` |
| Jump to cue | `;` | `'` |
| Set cue at current position | Shift + `;` | Shift + `'` |
| Stop (back to start) | `.` | `/` |
| Hot cues 1–4 | `1` `2` `3` `4` | `7` `8` `9` `0` |
| Clear a hot cue | Shift + `1`–`4` | Shift + `7`–`0` |

```
  1 2 3 4      7 8 9 0   ← hot cues (A, B)
  [ ]      ← play / pause      (A, B)
   ; '     ← cue               (A, B)
    . /    ← stop              (A, B)
```

---

## 3. MIDI controller layout

### Akai MPK Mini Mk II (Rob's controller)

The knobs are arranged in columns: the top row is Deck A and the bottom row is Deck B.

```
        col 1          col 2                 col 3                 col 4
top     K1 A volume    K2 A pitch (coarse)   K3 A pitch (fine)     K4 master
bottom  K5 B volume    K6 B pitch (coarse)   K7 B pitch (fine)     K8 headphones

pads, bank A (bottom row):
        pad 1 A play/pause   pad 2 A cue   pad 3 B play/pause   pad 4 B cue

pads, bank B (press PAD BANK), hot cues:
        top row      pads 5-8 = Deck B hot cues 1-4
        bottom row   pads 1-4 = Deck A hot cues 1-4
```

| Control | Does |
|---|---|
| K1, K5 | Channel volume for Deck A, Deck B |
| K2, K6 | Coarse pitch, −16% to +16%. The knob's centre is 0%. |
| K3, K7 | Fine pitch, an extra −1% to +1%, added to the coarse pitch |
| K4 | Master volume |
| K8 | Headphones volume (see the note below) |
| Pad 1, pad 3 | Play / pause for Deck A, Deck B |
| Bank B pads | Hot cues. An empty hot cue is set at the playhead. A set one jumps there. |
| Pad 2, pad 4 | **Tap** (let go within 1 second): play from the cue. **Hold** for 1 second: set the cue at the moment you first pressed. |

- **Pitch pick-up.** The pitch knobs only take control once you turn them past the current pitch. This stops the pitch jumping when the knob and the screen disagree, for example after you move the on-screen pitch fader.
- **Pitch display.** The screen shows pitch in percent and semitones. With no key lock, +16% speed raises the key by about 2.57 semitones.
- **Tempo readout.** The purple number above each pitch fader is the deck's tempo as it plays: the track's BPM × the pitch speed, for example `155.72`. The BPM is detected when the track loads, searching 90 to 180 BPM, so a slow song may show double its tempo. It shows `---.--` until detection finishes. In Settings, **Prefer BPM from the MP3 tag** uses the file's own BPM tag instead, when it has one.
- **Tap timing.** A tap is recognised when you let go, so play-from-cue starts on release.
- **Factory settings.** This layout needs the controller on its factory program 1: knobs on CC 1 to 8 and pads on notes 44 to 51, all on MIDI channel 1. The app was checked against your unit's own settings.
- **Piano keys.** The keys share channel 1 with the pads. At the default octave they don't overlap pads 1 to 4. If you shift the keys down an octave, some keys will act as pads.

### Hot cues

Each deck has 4 hot cue buttons under its transport controls, coloured like Serato's.

- **Set and jump.** Clicking an empty button sets that hot cue where the track is. Clicking a set button jumps there, and the deck keeps playing or stays paused.
- **Clear.** Shift + click empties a hot cue.
- **Waveform.** Each set hot cue shows as a numbered flag on the waveform.
- **Serato cues.** If an MP3 was prepared in Serato DJ, its first 4 hot cues load with the track, with their colours and names.
- **Not saved yet.** Hot cues last until the page is reloaded. Saving them is planned, in `_PLANS/005_write-perm_storage-savefeature`.

### Other controllers (generic layout)

Unknown controllers get the generic layout. It suits an 8-knob, 8-pad controller with factory numbers like the MPK Mini mk3's.

| Control | Does |
|---|---|
| Knob 1 | Master volume |
| Knob 2, knob 3 | Deck A, Deck B channel volume |
| Knob 4 | Headphones volume |
| Pads 1–4 | Deck A: play/pause, jump to cue, stop, set cue |
| Pads 5–8 | Deck B: the same |

### Headphones on a laptop

A laptop has one stereo output, so there is no separate headphone signal yet. For now the headphones control sits after the master on the same output. Turning it down turns everything down.

Planned options for a real headphone cue:
- **Split cue.** Master in your left ear and the cue mix in your right, over one pair of wired headphones. No extra hardware needed.
- **Second output device.** The cue mix goes to Bluetooth headphones while the laptop speakers play the master. Bluetooth delay makes beat matching harder.
- **A DJ mixer or sound card with 4 output channels**, such as the DJM-S9. Chrome can sometimes address more than 2 channels on such devices. This is untested.

---

## 4. Hardware

| Device | Status | Notes |
|---|---|---|
| **Akai MPK Mini Mk II** | Designed for (Rob's controller). Numbers read from the device itself. Not yet tested by hand. | Profile `akai_mpk_mini_mk2.yaml`. Layout in section 3. Class compliant: no driver or mode needed. |
| **Akai MPK Mini mk3** | Considered. Uses the generic profile. | Factory knob and pad numbers match the generic layout. |
| **Akai MPC (8 pads, 4+ knobs)** | Considered. Uses the generic profile. | A standalone MPC must be in Controller Mode to appear as a MIDI device. |
| **Akai MPD226** | Designed for. Not yet tested on hardware. | 16 pads and 4 faders. Only pads 1–8 are used. The 4 faders follow the table in section 3. |
| **Pioneer DJM-S9** | Considered. Partial mapping planned. | Used only as a MIDI fader surface: **crossfader** and **channel faders 1 and 2**. Its own audio interface is not used yet. |

### Profiles

Each device has a mapping file in `assets/midi_profiles/`, written in YAML with comments. The app picks a profile by matching the MIDI device name. Anything unrecognised uses `generic.yaml`.

Numbers in profiles marked `verified: false` are not yet confirmed on hardware. If a control does nothing:

1. Open Settings and move the control.
2. Read the **Last MIDI message** line, for example `CC 21 · ch 1 · 64`.
3. Put that number into the matching line of the profile and rebuild.

### Changing a mapping without rebuilding

In Settings, the **MIDI mapping** section lists each connected device:

| Control | Does |
|---|---|
| Profile list | **Automatic** picks by device name. You can also force any bundled profile, or your imported custom one. |
| **Export** | Downloads the mapping in use as a YAML file, with comments. Use it as a template for any controller. |
| **Import** | Loads an edited YAML file for this device. It's checked first, and an error names the line that's wrong. |
| **Reset** | Forgets your choice and custom file, and goes back to Automatic. |

Your choices are saved in this browser, per device.

---

## 5. Troubleshooting

| Problem | Fix |
|---|---|
| "MIDI not supported in this browser" | Use Chrome or Edge. |
| "Permission denied" | Re-allow MIDI in the site settings, then reload. |
| "No MIDI device found" | macOS can't see the controller. Plug it straight into the Mac with a cable known to carry data. A controller that lights up can still have no data connection. Close other apps that hold the device open, such as a DAW. Full steps: `_DEVELOPER_NOTES/_NON_HUMAN_NOTES/midi_usb_troubleshooting.md`. |
| Controller shows in `ioreg` or System Information but not in Audio MIDI Setup | macOS security is holding it back. Open **System Settings → Privacy & Security**, set **Allow accessories to connect** to **Automatically when unlocked**, and approve the accessory if asked. |
| Keyboard keys do nothing | Click once on the page so the browser window has focus. |
| A fader jumps when first moved | Expected. The on-screen value snaps to the hardware position. |
