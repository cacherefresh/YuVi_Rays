# DJ Hardware Setup — Stokyo Kutter, Akai controllers, VST

How to wire up a Stokyo Kutter crossfader, an Akai MPK Mini or MPD218/226,
and how VST loading works today vs. what's coming in the Desktop app.

## Before anything: browser requirement for MIDI

YuVi Rays' MIDI-Learn engine uses the **Web MIDI API**, which only exists in
**Chrome, Edge, and Opera** — it is **not supported in Safari or Firefox**.
If your controller doesn't show up, check your browser first. Open the MIDI
panel (piano icon, top right) — if it shows a warning banner, switch
browsers.

## Stokyo Kutter (crossfader)

The Kutter is a **passive mechanical crossfader replacement** — it's a
pot/contact assembly with no MIDI or USB output of its own. It only sends
MIDI once it's installed inside a mixer or controller that has USB-MIDI
output (many club mixers, some DIY builds), or paired with a separate
pot-to-MIDI interface (e.g. a small microcontroller reading the Kutter's
wiper and emitting a CC).

**Recommended setup:** wire the Kutter as a **MIDI position sensor only** —
don't route real audio through it. Let YuVi Rays' own equal-power crossfade
curve do the actual mixing in software; the Kutter just tells the app where
the crossfader is. This avoids double-crossfading (once in the hardware,
once in the app) and keeps the feel consistent regardless of which mixer
the Kutter happens to be installed in.

To map it:
1. Plug in whatever mixer/interface the Kutter is wired to.
2. Open **MIDI mapping** (piano icon, top right).
3. Click **Learn** next to **Crossfader**.
4. Move the Kutter fully across — the app binds to whatever CC it sends.

## Akai MPK Mini (mk2/mk3)

Plug in via USB. When prompted, allow MIDI access in the browser. A default
mapping applies automatically:

| Control | Maps to |
|---|---|
| Knob 1 | Deck A volume |
| Knob 2 | Deck B volume |
| Knob 3 | AUX/VST channel volume |
| Knob 4 | AUX/VST channel gain |
| Pad 1 / 2 / 3 | Deck A play-pause / cue (jump) / stop |
| Pad 4 / 5 / 6 | Deck B play-pause / cue (jump) / stop |

The MPK Mini has no motorized/linear faders — its knobs fill the "first
faders = the channel faders" role instead. Pads 7-8 and the keyboard are
left unmapped.

This is a **factory-typical default**, not a guarantee — Akai firmware and
custom programs vary. If a knob or pad doesn't match, open the MIDI panel
and re-**Learn** it individually; your override persists over the preset.

## Akai MPD218 / MPD226

Same idea, plug in via USB, default mapping applies (bank A / program 1):

| Control | Maps to |
|---|---|
| Q-Link knob 1 | Deck A volume |
| Q-Link knob 2 | Deck B volume |
| Q-Link knob 3 | AUX/VST channel volume |
| Pad 1 / 2 / 3 | Deck A play-pause / cue (jump) / stop |
| Pad 4 / 5 / 6 | Deck B play-pause / cue (jump) / stop |

Neither the 218 nor the 226 has true faders — the Q-Link knobs are used the
same way as above. Pads 7-16 are left unmapped for now. As with the MPK
Mini, re-**Learn** anything that doesn't match your unit.

## Applying a preset / re-mapping anything

Open the piano icon in the top-right of the app bar. You'll see every
mappable control, its current mapping, and a **Learn** button. Preset
buttons at the top apply the Akai tables above in one click; **Clear all**
wipes every mapping if you want to start over.

## VST loading — today vs. the Desktop app

Browsers can't execute native VST/VST3/AU plugin binaries — that's a
hard sandboxing limit, not something any web app can work around. So on
the current web build, the third channel (toggle **Desktop Mode**, top
right, to reveal it) is a **virtual-audio-input strip**: no VST loads
inside the browser, but you can route the output of a real VST — running
standalone or inside Ableton/Logic/any DAW — into that channel today:

1. Install a virtual audio cable: **BlackHole** on macOS, **VB-Cable** on
   Windows.
2. Set your DAW's or standalone host's audio output device to the virtual
   cable.
3. In YuVi Rays, toggle **Desktop Mode**, then in the AUX/VST channel's
   input dropdown select the virtual cable as the input device.
4. The VST's audio now mixes into YuVi Rays through the AUX channel's gain
   knob and fader, same as either deck.

**What's coming:** a native YuVi Rays Desktop app (macOS/Windows) with a
real VST3/AU plugin host built on JUCE, so the AUX channel can load an
actual plugin file directly instead of routing audio in via a virtual
cable. The scaffolding for this lives in `native/yuvi_vst_host/` and
`packages/yuvi_vst_engine/` — see `native/yuvi_vst_host/README.md` for
current status and the phased build-out plan. It isn't functional yet.
