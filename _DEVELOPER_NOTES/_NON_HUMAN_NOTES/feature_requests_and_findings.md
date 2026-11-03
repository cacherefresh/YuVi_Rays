<!--
  Written by Claude (AI). Rob's own notes live one level up in
  _DEVELOPER_NOTES/notes_bugtracker_feature_request. Claude reads that file
  for new requests but does not write to it.
-->
YuVi Rays — Bug Tracker & Feature Requests
==========================================
Claude's write-up of Rob's requests. Rob's own notes: ../notes_bugtracker_feature_request
Claude: if you see a better way, say so (see AGENTS.MD → "Working agreement").
Detailed implementation plans live in ../../_PLANS/.

Status legend: [ ] open   [~] planned   [x] done   [?] needs decision


------------------------------------------------------------------
FR-001  MIDI controller support (opt-in setting)          [~] → _PLANS/001
------------------------------------------------------------------
Logged: 2026-11-02   Branch: feature/midi_hardware_plus_crossfader_via_audio

Request (as written by Rob):
  - Add an option setting that makes Chrome show its permission dialog
    asking whether to connect the MIDI controller hardware.
  - Controller in mind: Akai MPC-style unit with 8 touch-sensitive
    (velocity) pads and at least 4 fader knobs.
  - Fader 1 = MASTER volume
  - Fader 2 = Deck A channel volume to master
  - Fader 3 = Deck B channel volume to master
  - Fader 4 = HEADPHONES volume
  - For now headphones volume = same signal as master out. On a laptop
    there is no second stereo output (no external sound card while
    travelling; MacBook Pro). Must work on the WEB build in Chrome,
    deployed to GitHub Pages.

Notes / findings:
  - Web MIDI API: navigator.requestMIDIAccess(). Chrome shows a
    permission prompt for it (since Chrome 124, even without SysEx).
    Needs a secure context: https (GitHub Pages) or localhost — both OK.
  - Chrome remembers the grant per origin, so the prompt appears once.
    The setting should only trigger the request when the user switches
    it ON (user gesture), never on page load.
  - Safari and Firefox-on-mac have limited / no Web MIDI. Chrome/Edge only.
  - The exact Akai model matters for CC numbers (LPD8, MPK Mini, MPD218
    all differ). Mappings should be DATA (a JSON profile) plus a
    "MIDI learn" mode, not hard-coded CC numbers.
  - Pads were not assigned. Proposal in _PLANS/001 (pads 1-4 = Deck A
    play/cue/stop/set-cue, pads 5-8 = Deck B).

Headphones / cue on a single laptop output — options found:
  a) Mirror master (requested for v1). Fader 4 scales a separate
     "headphones" gain node that, for now, feeds the same output.
  b) SPLIT CUE (what Mixxx calls "split" mode): master summed to mono
     in the LEFT ear, cue/headphone bus summed to mono in the RIGHT ear,
     on the one stereo output. Works today on any laptop with wired
     headphones. Recommended as the v2 step.
  c) Second output DEVICE: route the headphone bus through a
     MediaStreamAudioDestinationNode → <audio>.setSinkId(deviceId).
     On a MacBook this works with Bluetooth headphones (AirPods) as the
     cue device while speakers play master. Bluetooth latency
     (~150-250 ms) makes it so-so for beat matching. Chrome only.


------------------------------------------------------------------
FR-002  Keyboard shortcuts for transport                  [~] → _PLANS/001
------------------------------------------------------------------
Logged: 2026-11-02

Request: map keys so each deck's controls line up DOWN the keyboard.
  Deck A (left)  :  {   :   >     →  play/pause, cue, stop
  Deck B (right) :  ]   '   /     →  play/pause, cue, stop

Interpretation (to confirm):
  These are the two diagonal key columns on a US keyboard:
    Deck A:  [  ;  .     (same physical keys as { : >)
    Deck B:  ]  '  /
  Bind by PHYSICAL key (KeyboardEvent.code: BracketLeft, Semicolon,
  Period / BracketRight, Quote, Slash) so Shift is not required and
  non-US layouts still get the same physical positions.

  "Cue" today = two buttons (CUE sets, ►CUE jumps). Proposed:
    key       → jump to cue
    Shift+key → set cue at current position


------------------------------------------------------------------
FR-003  Crossfader via the audio graph                    [?]
------------------------------------------------------------------
Implied by the branch name. Today the crossfader is computed in Dart
(MixerProvider) and multiplied into each deck's volume node. Moving it
into the Web Audio graph (a gain node per deck after the channel
fader) keeps channel fader and crossfader independent and makes the
audio-graph view show it. Folded into _PLANS/001 Phase 1.


------------------------------------------------------------------
OPEN: Rob's message ended with "i also want ..." — the rest was cut off.
------------------------------------------------------------------


------------------------------------------------------------------
FR-004  Serato-style hot cues (4 per track)               [~] → _PLANS/002
------------------------------------------------------------------
Logged: 2026-11-02

Request: 4 cue points that can be saved to the track, like Serato.
Must read cue points already saved on a track by Serato.

Findings:
  - Serato writes cues into the MP3's ID3v2 tag, GEOB frame
    "Serato Markers2" (base64-wrapped binary list of CUE/COLOR/LOOP
    entries). Older versions use "Serato Markers_". Serato has 8 slots.
  - Local files already reach Dart as bytes (deck_widget file picker),
    so the tag can be parsed in pure Dart before handing a blob URL to
    Tone.js.
  - "Save to the track": writing into the file in place needs Chrome's
    File System Access API and risks damaging Rob's Serato library.
    Recommend browser storage (IndexedDB keyed by file hash) first,
    write-back later as an opt-in. Details in _PLANS/002.
  - Status: planned only. Building plan 001 first, per Rob.


------------------------------------------------------------------
FR-005  DJ_SETUP_INSTRUCTIONS.md                           [x]
------------------------------------------------------------------
Logged: 2026-11-02

Root-level guide covering hardware setup, every key/pad/fader, and the
hardware list: Akai MPC, Akai MPD226, Pioneer DJM-S9 (crossfader and
channel faders over MIDI only). Keep it updated when mappings change.

Finding: the DJM-S9 is also a USB audio interface with a separate
headphone/booth output. Chrome may expose more than 2 output channels
on such devices (AudioContext.destination.maxChannelCount), which could
give a real headphone cue. Untested; noted for the headphone plan.


------------------------------------------------------------------
2026-11-02  Build notes: FR-001, FR-002, FR-003
------------------------------------------------------------------
Built plan 001 phases 1-3. Defaults used for the open questions:
  - Pads 1-4 = Deck A play/cue/stop/set-cue, 5-8 = Deck B.
  - Headphone fader is in series after master.
  - Cue key jumps; Shift + cue key sets.
Verified: unit tests (yuvi_input 15, yuvi_audio_engine 4), flutter
analyze, flutter build web --base-href /.
NOT verified: running in Chrome, the MIDI permission prompt, real
hardware. All CC numbers in assets/midi_profiles are unverified guesses.
Gotcha: Node isn't installed on Rob's Mac. JS syntax was checked with
`osascript -l JavaScript` (JavaScriptCore) instead.


------------------------------------------------------------------
FR-006  MPK Mini Mk II layout, pitch knobs, hold-cue, MIDI config [~] → _PLANS/003
------------------------------------------------------------------
Logged: 2026-11-03

Request (Rob):
  K1 = Deck A volume, K5 = Deck B volume.
  K2/K6 = coarse pitch A/B (-16..+16%), K3/K7 = fine pitch A/B (extra +/-1%).
  Pad 1 = Deck A play, second hit stops.
  Pad 2 = tap (<1 s) play from cue; hold >=1 s sets cue at the press position.
  Asked: where/how are settings stored (.yaml?), how will knobs work, is there
  a "set MIDI config" override so a generic device can be swapped in.

Findings:
  - Existing bug: yuvi_bridge.js position = offset + (now - startTime),
    ignoring playbackRate. Playhead, cue and end detection drift when
    pitch != 0. Must fix before pitch is MIDI-driven.
  - On-screen pitch is in semitones (+/-7), not percent. Plan 003 moves to
    percent (+/-16%).
  - Tap vs hold can only be decided on release, so play-from-cue fires on
    release (~50-150 ms later than a plain button). Flagged as Q5.
  - Profile CC 70-73 is the mk3 default; Mk II is believed to be CC 1-8.
    Must verify with the Settings MIDI monitor.
  - There is no user override of mappings yet. Plan 003 adds a
    three-layer model: user (localStorage) > bundled by device name > generic.


------------------------------------------------------------------
FR-007  First-visit pop-up pointing to MIDI settings           [x]
------------------------------------------------------------------
Logged and built: 2026-11-03

Request: a pop-up on first landing telling people to check Settings to
connect MIDI devices.

Built: lib/settings/midi_hint_dialog.dart, called once from MixerScreen.
  - Shown once ever per browser (localStorage key
    yuvi.onboarding.midiHintSeen), marked seen as soon as it shows.
  - Skipped if the browser has no Web MIDI (Safari) or MIDI is already on.
  - Buttons: "Not now" and "Open Settings" (opens the settings dialog).
  - Also mentions the keyboard shortcuts.
Verified in Chrome via CDP screenshot after clearing localStorage.


------------------------------------------------------------------
2026-11-03  "MIDI doesn't seem to work" + fake MIDI test runner (FR-006)
------------------------------------------------------------------
Cause: profile numbers were wrong (CC 70-73 / notes 36-43 ch 10) vs the
real Mk II (CC 1-8 / notes 44-51 ch 1). Read from the device via SysEx.
Also fixed: the song list never loaded (manifest format, MP3s not bundled,
NFD vs NFC Unicode file name, wrong asset URL).
Built plan 003 phases 1-4 and 6, the fake MIDI runner test (runs on PRs),
a live smoke test and a capture script. Full write-up:
debugging_midi_mapping.md.
Open: confirm the pad "mode" byte means momentary, with one real press.
Note: the MP3 Rob added is a commercial song, not royalty-free. The
folder is git-ignored, so it isn't committed or deployed.


------------------------------------------------------------------
FR-007b Tempo (BPM) readout above the pitch fader              [x] → _PLANS/004
------------------------------------------------------------------
Logged and built: 2026-11-03
Purple (#B388FF, 75%) 000.00 readout = base BPM x playback rate.
Base BPM = web-audio-beat-detector (8.2.31, /+esm build) at load time, or
the ID3 TBPM tag when the new setting "Prefer BPM from the MP3 tag" is on
(default off). Each falls back to the other. New package
yuvi_track_metadata (pure Dart ID3v2 reader). Verified live: 150.00, then
155.72 at +3.81%.


------------------------------------------------------------------
FR-008  Track metadata cache (future, separate feature)         [ ]
------------------------------------------------------------------
Logged: 2026-11-03

Request (Rob): later, a YAML file capturing the metadata of all tracks
(detected BPM, cues, etc.), so tracks load faster next time without
writing to the MP3 tags. "It can be saved in a permanent cookie
eventually."

Better way to flag when planned:
  - Cookies are a poor fit: about 4 KB per cookie, sent to the server with
    every request, and Chrome caps lifetime at 400 days (there is no truly
    permanent cookie). A library of tracks outgrows that quickly.
  - Recommend IndexedDB (large, persistent, per-site), keyed by a hash of
    the file's bytes, so a renamed file keeps its data. Optionally ask the
    browser for persistent storage (navigator.storage.persist()).
  - Keep YAML as the export/import format (fits the YAML profiles), e.g.
    "Export library metadata" / "Import" in Settings, so the data can be
    backed up or moved to another machine.
  - Overlaps plan 002 (hot cues stored in IndexedDB by file hash). Plan
    both on one storage layer, e.g. a reusable yuvi_track_library package.


------------------------------------------------------------------
2026-11-03  Split: read side built, write side deferred
------------------------------------------------------------------
Rob: plan the two writable things as feature/write-perm_storage-savefeature
(two sub-bullets) and defer; do the readable and controller work now.
  Deferred: _PLANS/005  A. track metadata cache (FR-008)
                        B. hot cue saving / write-back (FR-004 saving)
  Built:    Serato Markers2 reading, 4 hot cues per deck in memory,
            hot cue keys (1-4 / 7-0) and MPK bank B pads, Settings MIDI
            mapping (choose / export / import / reset), plan 003 done.
Verified live: 10/10 smoke steps incl. hot cue via bank B pad; hot cue 2
set by the "2" key; mapping section shows the connected MPK Mini Mk II.


------------------------------------------------------------------
2026-11-03  Removed assets/royalty_free_audio/manifest.json
------------------------------------------------------------------
Rob asked whether the manifest was needed. It wasn't: since the whole folder
is bundled, Flutter's own AssetManifest lists the files. The manifest only
offered custom display names, ordering and hiding files, and it caused the
NFC/NFD file-name mismatch. Now:
  - The song menu lists every audio file in the folder (mp3, m4a, aac,
    wav, ogg, flac), sorted, named by file name. lib/util/unicode_nfc.dart
    was deleted (no longer needed).
  - .gitignore: assets/royalty_free_audio/* plus !.gitkeep, because
    pubspec.yaml bundles the folder and a missing folder fails the build.
    The empty .gitkeep is bundled too; the app ignores non-audio files.
  - Verified: a copy with only committable files (no MP3) passes all
    tests and `flutter build web`; live smoke test passes.

------------------------------------------------------------------
2026-11-03  First real Serato file decoded
------------------------------------------------------------------
~/Music/YUVI-TRAX/dnb/V O E - Asking For It (VIP) (1).mp3 (read-only).
ID3v2.3, TBPM 88 (half of drum & bass 176). GEOB frames: Serato Overview,
Analysis, Autotags, Markers_, Markers2, BeatGrid. Markers2 decoded to 6 hot
cues: 0.235 s, 44.122, 55.090, 166.185, 170.288, 178.597, with colours.
The app shows slots 1-4, so cues 5 and 6 aren't shown.
Serato keeps MP3 hot cues IN THE FILE (GEOB tags). ~/Music/_Serato_/
"database V2" only lists the file path (plus crates and history).

### 2026-11-03: MPK Mini Mk II K8 → crossfader

- Rob asked for K8 to drive the crossfader: full left = min (Deck A), full right = max (Deck B), knob centre = crossfader centre.
- `KnobAction.crossfader` is now `centred`: `KnobBinding.scale` maps 64 to exactly the middle of the range (0.5), not 64/127 ≈ 0.504.
- K8 no longer controls headphones; headphones volume is on screen only. Takeover is `jump` (default), so the crossfader follows the knob at once.
- Tests: `KnobBinding.scale` crossfader case (yuvi_input) and "K8 crossfader" in test/midi_fake_runner_test.dart.

### 2026-11-03: MPK Mini Mk II pads 5-8 → hot cues 1-2

- Bank A pads 5, 6 (notes 48, 49) = Deck A hot cues 1, 2. Pads 7, 8 (notes 50, 51) = Deck B hot cues 1, 2. Same `hotCue` action as bank B: empty sets at the playhead, set jumps.
- Clash: the piano keys share channel 1 and start at note 48 at the default octave, so keys C..D# also fire these. Fix on the device: OCT+ once, or change the pad notes in the Akai editor (then update the YAML).
- Tests: "bank A pads 5-8" group in test/midi_fake_runner_test.dart; the layout test now expects pads 5-8 as hot cues.
