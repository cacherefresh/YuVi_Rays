# MIDI controller and USB hub troubleshooting (macOS)

*Written by Claude. First used 2026-11-02, when the YuVi Rays settings dialog said "No MIDI device found".*

Work from the bottom up. Each layer needs the one below it to be working:

```
USB connection  →  macOS MIDI (CoreMIDI)  →  Chrome Web MIDI  →  YuVi Rays
```

If macOS can't see the controller, Chrome and the app never will. Check macOS first.

---

## 1. Can macOS see the device on USB?

### Show the USB device tree

```
ioreg -p IOUSB -w0 | sed 's/<class.*//'
```

Each `+-o` line is one USB device. Devices plugged into a hub appear indented under it.

**Working:** the controller appears by name, for example `MPD226@...` under `USB2.1 Hub@...`.

**What we saw on 2026-11-02, with the controller not detected:**

```
+-o Root
  +-o AppleT8132USBXHCI@02000000
  +-o AppleT8132USBXHCI@00000000
  +-o AppleT8132USBXHCI@01000000
    +-o USB3.1 Hub@01200000
    +-o USB2.1 Hub@01100000
```

Both hubs were detected, but nothing was listed under them. So the hub reached the Mac, and the controller never reached the hub.

### List just the product and vendor names

```
ioreg -p IOUSB -l -w0 | grep -i '"USB Product Name"\|"USB Vendor Name"' | sort -u
```

Look for `Akai` or the model name.

### Search the full system report

```
system_profiler SPUSBDataType SPUSBHostDataType 2>/dev/null | grep -i -B2 -A12 "akai\|mpd\|mpk\|mpc\|lpd\|midi"
```

No output means no Akai or MIDI device was found.

On macOS 15.1 (Rob's Mac) only `SPUSBDataType` exists. `SPUSBHostDataType` prints nothing there, with no error. To see which USB report names your macOS has, run `system_profiler -listDataTypes | grep -i usb`. Asking for both names, as above, works on any version.

The same information is in the GUI: Apple menu, **About This Mac**, **More Info**, **System Report**, then **USB**.

---

## 2. Does macOS offer it as a MIDI input?

### Count MIDI devices and inputs

```
osascript -l JavaScript -e 'ObjC.import("CoreMIDI"); "devices=" + $.MIDIGetNumberOfDevices() + "  sources=" + $.MIDIGetNumberOfSources()'
```

- `devices` includes macOS's own virtual devices (IAC Driver, Network, Bluetooth). It is rarely 0.
- `sources` is the number of MIDI **inputs** that apps, including Chrome, can read. This is the number that matters.

**Working:** `sources=1` or more with the controller plugged in.
**What we saw:** `devices=3  sources=0`. That means no hardware MIDI input at all.

This uses JavaScript for Automation, which is built into macOS, so nothing needs installing. Getting device *names* this way doesn't work. Use Audio MIDI Setup for names.

### Audio MIDI Setup (GUI, shows names)

1. Open **Audio MIDI Setup** (Spotlight: "Audio MIDI Setup").
2. Choose **Window → Show MIDI Studio**, or press ⌘2.
3. The controller should appear as an icon that is **not greyed out**. A greyed-out icon is a device macOS saw before but can't see now.

### Is the macOS MIDI service running?

```
pgrep -lf MIDIServer
```

**Working:** one line ending in `CoreMIDI.framework/MIDIServer`. It starts automatically when an app uses MIDI.

---

## 3. Chrome and the app

Only check this once section 2 shows `sources` of 1 or more.

- In YuVi Rays, click the gear icon and turn on **Enable MIDI controller**. The status should say **Connected** with the device name.
- Move a control. The **Last MIDI message** line should change.
- If the status says permission denied, click the icon left of the address bar, open **Site settings**, set **MIDI devices** to **Allow**, and reload.
- The app picks up devices plugged in later. If it doesn't, turn the switch off and on.

---

## 4. Likely causes when the controller lights up but isn't detected

Lights only prove the controller has power. Try these in order:

1. **Power-only cable.** Many micro-USB and USB-B cables only carry power. Use a cable known to carry data.
2. **Hub.** Plug the controller straight into the Mac with a USB-C to USB-B or micro-USB cable. Bus-powered hubs may power the lights but not keep data stable.
3. **Hub port.** Some ports on cheap hubs are charge-only.
4. **Controller mode.** A standalone MPC (One, Live, X) must be in **Controller Mode**, or have USB MIDI enabled in its settings. MPD and MPK models need no setting.

**Rob's controller is an Akai MPK Mini.** It is USB class compliant: no driver, no mode, and powered over the USB cable. If it lights up but isn't detected, the cause is the cable, the hub, or the hub port. It is never a setting. When it connects, it appears in Audio MIDI Setup with "MPK mini" in its name.

After each change, run the `ioreg` tree command from section 1 again.

---

## 5. Side issue from the same session: "404 not found" on localhost

The local Flutter server showed a 404 because another server already had port 8080.

### What is listening on a port

```
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

On 2026-11-02 this showed two listeners: Flutter's `dartvm` and a `Python` server.

### What a process is and how long it has run

```
ps -o pid,ppid,etime,command -p <PID>
```

`etime` is the time since it started (`days-hh:mm:ss`). `command` shows the full command line. The Python server turned out to be a `python3 -m http.server 8080` that a Claude session on another project had started in the background about 16 days earlier. Closing that session didn't stop it.

### Which folder a server is serving

```
lsof -a -p <PID> -d cwd -Fn | tail -1
```

### Test what a URL returns, from the terminal

```
curl -sI http://localhost:8080/ | head -3
```

The `Server:` line names the server that answered. `SimpleHTTP/... Python` means the Python server, not Flutter.

### Find a free port

```
for p in 8090 8091 5050; do lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null && echo "$p busy" || echo "$p free"; done
```

### Fixes

- Run Flutter on a free port: `flutter run -d chrome --target lib/web_main.dart --web-port 8090`
- Or stop the stray server: `kill <PID>`

---

## 6. What didn't work

- **A Swift script using CoreMIDI.** `swift midils.swift` failed with *"this SDK is not supported by the compiler"*. The Command Line Tools' Swift compiler and SDK are out of step on this Mac. Reinstalling or updating Command Line Tools would fix it, but the JavaScript for Automation command in section 2 does the same job without that.
- **Node.js** isn't installed. JavaScript syntax checks for `web/js/yuvi_bridge.js` used macOS's JavaScriptCore through `osascript -l JavaScript` instead.

---

## 7. Detected on USB but no MIDI input (found 2026-11-03)

If the controller appears in the `ioreg` tree but `sources` stays 0, check its setup status:

```
ioreg -p IOService -w0 | grep -i "mpk"
```

`!registered, !matched` means macOS read the device but held it back. On Rob's MacBook this was **accessory security**. The fix was **System Settings → Privacy & Security → Allow accessories to connect → Automatically when unlocked**. Afterwards the line read `registered, matched` and `sources=1`.

