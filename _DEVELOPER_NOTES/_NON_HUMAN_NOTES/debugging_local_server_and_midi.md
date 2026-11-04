# Debugging the local server and "No MIDI device found"

*Written by Claude, 2026-11-02. A step-by-step record of debugging the running app with both debuggers that `flutter run -d chrome` provides.*

Companion note: [midi_usb_troubleshooting.md](midi_usb_troubleshooting.md) covers the macOS USB and MIDI checks in more depth.

---

## Summary

| Question | Answer | How we know |
|---|---|---|
| Does the local server work? | Yes, on port 8090. | The app loaded at `http://localhost:8090/`. |
| Is the page allowed to use MIDI? | Yes. It is a secure context and `requestMIDIAccess` exists. | Chrome debugger, step 3 |
| Did the app's code load correctly? | Yes. The audio bridge and Tone.js are loaded, and Dart reports MIDI as supported. | Chrome debugger step 3, Dart debugger step 7 |
| Does macOS see the controller? | **No.** No USB device behind the hubs, and 0 MIDI inputs. | Step 6 |
| Root cause | **The USB connection, not the app.** Most likely a power-only cable or the hub. | See the companion note, section 4 |

The app's "No MIDI device found" message was correct.

---

## The two debuggers

`flutter run -d chrome` gives you two separate debuggers. Both talk JSON over a WebSocket.

| | Chrome DevTools Protocol (CDP) | Dart VM Service |
|---|---|---|
| What it debugs | The browser page: JavaScript, permissions, reloads | The Dart code of the Flutter app |
| Where the address comes from | The `--remote-debugging-port` Flutter passes to Chrome | Printed by `flutter run` |
| Address shape | `ws://127.0.0.1:<chrome-port>/devtools/page/<id>` | `ws://127.0.0.1:<port>/<token>=/ws` |
| Message shape | `{"id":1,"method":"Runtime.evaluate","params":{...}}` | `{"jsonrpc":"2.0","id":"1","method":"evaluate","params":{...}}` |
| Browser UI | Chrome's own DevTools (F12 / ⌥⌘I) | The `http://127.0.0.1:<port>/<token>=/devtools/?uri=ws://...` link |

The `devtools/?uri=ws://...` link you can open in a browser is the **Dart** debugger's web UI, not Chrome's.

Ports and tokens change on every run. The values below are from this session. Find yours with step 2.

### Helper script

Python on this Mac has no WebSocket library and Node isn't installed, so a small Dart script sends the commands: [`tool/ws_rpc.dart`](../../tool/ws_rpc.dart).

```
dart run tool/ws_rpc.dart <ws-url> '<json message>' ['<json message>' ...]
```

It sends each message, waits up to 15 seconds for the reply with the same `id`, and prints the reply. It works with both debuggers.

---

## Step 1. Start the app

```
flutter run -d chrome --target lib/web_main.dart --web-port 8090
```

Port 8090 avoids the clash on 8080 described in the companion note. Wait for these lines:

```
A Dart VM Service on Chrome is available at: http://127.0.0.1:64617/YhSPSxq5GW4=
The Flutter DevTools debugger and profiler on Chrome is available at: http://127.0.0.1:64617/YhSPSxq5GW4=/devtools/?uri=ws://127.0.0.1:64617/YhSPSxq5GW4=/ws
```

The Dart VM Service WebSocket is that address with `/ws` on the end: `ws://127.0.0.1:64617/YhSPSxq5GW4=/ws`.

To run it in the background with a log file:

```
flutter run -d chrome --target lib/web_main.dart --web-port 8090 > flutter_run.log 2>&1 &
until grep -q "Dart VM Service" flutter_run.log; do sleep 1; done; cat flutter_run.log
```

## Step 2. Find Chrome's debugging port and the page

Flutter starts a separate Chrome with its own debugging port. Find it:

```
ps -axo command | grep -o "remote-debugging-port=[0-9]*" | head -1
```

Result: `remote-debugging-port=64578`.

List what Chrome has open, with each WebSocket address:

```
curl -s http://127.0.0.1:64578/json/version
curl -s http://127.0.0.1:64578/json/list | python3 -c "import json,sys; [print(t['type'], t['url'], t['webSocketDebuggerUrl']) for t in json.load(sys.stdin)]"
```

Result, trimmed:

```
page http://localhost:8090/ ws://127.0.0.1:64578/devtools/page/7822B8A6AC9D44154C20B78046597BB3
```

`/json/version` also gives the **browser** address (`.../devtools/browser/<id>`), which permission commands need.

For the commands below:

```
PAGE=ws://127.0.0.1:64578/devtools/page/7822B8A6AC9D44154C20B78046597BB3
BROWSER=ws://127.0.0.1:64578/devtools/browser/a1d599e4-532b-4336-a7a4-cbf53cab4ee3
VM=ws://127.0.0.1:64617/YhSPSxq5GW4=/ws
```

## Step 3. Chrome debugger: can the page use MIDI, and did the app load?

```
dart run tool/ws_rpc.dart $PAGE '{"id":1,"method":"Runtime.evaluate","params":{"expression":"({url: location.href, secure: isSecureContext, hasWebMidi: \"requestMIDIAccess\" in navigator, bridge: typeof window.YuViDVS, tone: typeof window.Tone, midiSetting: localStorage.getItem(\"yuvi.settings.midiEnabled\")})","returnByValue":true}}'
```

Result:

```
"url": "http://localhost:8090/", "secure": true, "hasWebMidi": true,
"bridge": "object", "tone": "object", "midiSetting": null
```

- `secure: true`: Web MIDI is allowed on this origin.
- `hasWebMidi: true`: this Chrome supports Web MIDI.
- `bridge` and `tone` are `object`: the audio bridge and Tone.js loaded.
- `midiSetting: null`: nothing saved yet in this Chrome profile. *(Correction, 2026-11-03: Flutter's Chrome profile is **not** always fresh. On the next day's run, `yuvi.settings.midiEnabled` was still `"true"`. Don't assume a clean slate. Clear it with `localStorage.clear()` to simulate a first visit.)*

The same expressions can be typed into the Console tab of Chrome's DevTools on the app's page.

## Step 4. Chrome debugger: MIDI permission state

```
dart run tool/ws_rpc.dart $PAGE '{"id":1,"method":"Runtime.evaluate","params":{"expression":"navigator.permissions.query({name:\"midi\"}).then(p => p.state)","awaitPromise":true,"returnByValue":true}}'
```

Result: `"prompt"`. Chrome will ask the user before giving MIDI access.

## Step 5. Chrome debugger: ask Chrome for its MIDI ports (and a dead end)

This lists every MIDI input and output Chrome can see. `Promise.race` adds a 5-second limit so the command can't hang on the permission prompt:

```
EXPR='Promise.race([navigator.requestMIDIAccess().then(a => ({inputs: [...a.inputs.values()].map(i => i.manufacturer + \" | \" + i.name + \" | \" + i.state), outputs: [...a.outputs.values()].map(o => o.manufacturer + \" | \" + o.name + \" | \" + o.state)}), e => \"rejected: \" + e.name), new Promise(r => setTimeout(() => r(\"still waiting on permission prompt after 5s\"), 5000))])'
dart run tool/ws_rpc.dart $PAGE "{\"id\":8,\"method\":\"Runtime.evaluate\",\"params\":{\"expression\":\"$EXPR\",\"awaitPromise\":true,\"returnByValue\":true}}"
```

Result: `"still waiting on permission prompt after 5s"`. A permission prompt appeared in the Chrome window.

**Dead end: granting MIDI permission through the debugger.** All of these replied `{"result":{}}`, meaning success. But the permission stayed `prompt`, even after a page reload:

```
# grant by permission name
dart run tool/ws_rpc.dart $BROWSER '{"id":2,"method":"Browser.grantPermissions","params":{"origin":"http://localhost:8090","permissions":["midi"]}}'

# set one permission explicitly
dart run tool/ws_rpc.dart $BROWSER '{"id":5,"method":"Browser.setPermission","params":{"origin":"http://localhost:8090","permission":{"name":"midi"},"setting":"granted"}}'

# grant midi and midiSysex, then reload the page
dart run tool/ws_rpc.dart $BROWSER '{"id":9,"method":"Browser.grantPermissions","params":{"origin":"http://localhost:8090","permissions":["midi","midiSysex"]}}'
dart run tool/ws_rpc.dart $PAGE '{"id":10,"method":"Page.reload","params":{}}'

# find the page's browser profile id, then grant in that profile
dart run tool/ws_rpc.dart $BROWSER '{"id":12,"method":"Target.getTargets","params":{}}'
dart run tool/ws_rpc.dart $BROWSER '{"id":13,"method":"Browser.grantPermissions","params":{"origin":"http://localhost:8090","permissions":["midi","midiSysex"],"browserContextId":"CEF1283B927E75E6213B8656768E1A05"}}'
```

Chrome 156 appears to ignore debugger grants for MIDI. **Workaround: click Allow in the Chrome window**, then run the step 5 command again. It will list the ports.

## Step 6. macOS: is there anything for Chrome to find?

Chrome can only list MIDI ports that macOS provides. Checking macOS directly gets around the permission prompt:

```
ioreg -p IOUSB -w0 | sed 's/<class.*//'
osascript -l JavaScript -e 'ObjC.import("CoreMIDI"); "devices=" + $.MIDIGetNumberOfDevices() + "  sources=" + $.MIDIGetNumberOfSources()'
```

Result, the same as earlier in the day:

```
    +-o USB3.1 Hub@01200000
    +-o USB2.1 Hub@01100000
devices=3  sources=0
```

No device behind the hubs, and **0 MIDI inputs**. Even with permission granted, Chrome would list no inputs. **This is the bug.**

## Step 7. Dart debugger: what does the running app think?

Get the VM and the isolate id:

```
dart run tool/ws_rpc.dart $VM '{"jsonrpc":"2.0","id":"1","method":"getVM","params":{}}'
```

Result: `"name": "ChromeDebugProxy"`, `"targetCPU": "Web"`, with one isolate `"id": "1050", "name": "main()"`.

List the libraries loaded in that isolate, to find the one to evaluate in:

```
dart run tool/ws_rpc.dart $VM '{"jsonrpc":"2.0","id":"2","method":"getIsolate","params":{"isolateId":"1050"}}' | grep -A3 -B3 'midi_input_source.dart"'
```

The library id is its URI: `package:yuvi_input/src/midi/midi_input_source.dart`.

Evaluate Dart inside that library:

```
LIB=package:yuvi_input/src/midi/midi_input_source.dart
dart run tool/ws_rpc.dart $VM \
  "{\"jsonrpc\":\"2.0\",\"id\":\"3\",\"method\":\"evaluate\",\"params\":{\"isolateId\":\"1050\",\"targetId\":\"$LIB\",\"expression\":\"MidiInputSource.isSupported\"}}" \
  "{\"jsonrpc\":\"2.0\",\"id\":\"4\",\"method\":\"evaluate\",\"params\":{\"isolateId\":\"1050\",\"targetId\":\"$LIB\",\"expression\":\"web.window.localStorage.getItem('yuvi.settings.midiEnabled')\"}}"
```

Results: `"kind": "Bool", "valueAsString": "true"` and `"kind": "Null"`. The Dart side agrees with Chrome: MIDI is supported, and the setting is empty in this fresh profile.

Evaluation works on static members and top-level code in a library. The app's live objects, such as the input controller, aren't reachable this way without a breakpoint. To inspect them, open the DevTools link from step 1, pause in the Debugger tab, and look at the variables.

---

## Conclusions

1. **The local server and the app are working.** The earlier 404 was a port clash on 8080. See the companion note, section 5.
2. **The MIDI code is working.** It reports "No MIDI device found" because macOS has no MIDI input to give it.
3. **The fix is physical.** Plug the controller straight into the Mac with a cable known to carry data, then re-run step 6 until `sources` is 1 or more.
4. **Testing tip.** Flutter's Chrome profile may or may not keep settings between runs (it kept them on 2026-11-03). For predictable MIDI testing, run `flutter run -d web-server --target lib/web_main.dart --web-port 8090` and open `http://localhost:8090` in your everyday Chrome. It remembers both.

## Re-test checklist once the controller is reconnected

1. Step 6 shows the device under a hub or USB port, and `sources` is 1 or more.
2. In the app, open Settings, turn on MIDI, and click **Allow**.
3. Step 5 lists the Akai under `inputs`.
4. Settings shows **Connected** and the device name. Moving a fader updates the **Last MIDI message** line.

---

## Follow-up: after clicking Allow and turning the setting on

Rob clicked **Allow** in Chrome's prompt and turned on the MIDI setting. The step 5 command, extended to also show the permission and the setting, returned:

```
"permission": "granted", "setting": "true", "inputs": [], "outputs": []
```

Step 6 still showed nothing behind the hubs and `sources=0`. So both software switches were on, and the only remaining cause is the USB connection.

### Why there are two switches

| Switch | Owned by | Purpose |
|---|---|---|
| Chrome's MIDI permission pop-up | Chrome | Whether this website may use MIDI at all. Remembered per site. |
| "Enable MIDI controller" in the app | YuVi Rays | Whether the app should listen to MIDI right now. |

In normal use you only act once: turning on the app setting triggers Chrome's pop-up the first time. On 2026-11-02 the pop-up appeared earlier because the debugger in step 5 asked for MIDI before the setting was on.

---

## Follow-up 2026-11-03: new cable, no hub

Rob plugged the controller straight into the Mac with a new cable.

**The USB connection now works.** The controller is an **MPK Mini Mk II**:

```
ioreg -p IOUSB -w0 | sed 's/<class.*//'
  +-o AppleT8132USBXHCI@02000000
  | +-o MPK Mini Mk II@02100000
```

`system_profiler SPUSBDataType` shows it too: vendor `AKAI professional M.I. Corp.`, Location ID `0x02100000`.

**macOS MIDI still has no input**, even after waiting 9 seconds:

```
osascript -l JavaScript -e 'ObjC.import("CoreMIDI"); "devices=" + $.MIDIGetNumberOfDevices() + "  sources=" + $.MIDIGetNumberOfSources() + "  external=" + $.MIDIGetNumberOfExternalDevices()'
devices=3  sources=0  external=0
```

**Why: macOS never finished setting the device up.** The device has no child interfaces, and it is marked not registered and not matched:

```
ioreg -p IOService -r -n "MPK Mini Mk II@02100000" -w0 | grep -- "+-o"
+-o MPK Mini Mk II@02100000  <class IOUSBHostDevice, ... !registered, !matched, active, busy 0 ...>
```

A healthy USB MIDI device has `registered, matched` and child `IOUSBHostInterface` entries underneath. The MIDI interface is one of those children, and macOS's MIDI service picks it up from there. The device's `UsbDeviceSignature` does include a MIDI-streaming interface (USB audio class `01`, subclass `03`), so the controller does offer MIDI. macOS just hasn't got that far.

The system log (`log show ...`) returned nothing from Claude's shell, so the reason setup stopped is unknown.

**Quick check for this state, from any terminal:**

```
ioreg -p IOService -w0 | grep -i "mpk"
```

`!registered, !matched` means stuck. `registered, matched` means set up, and `sources` should then be 1 or more.

**Fixes to try, in order:**
1. Unplug the controller, wait 10 seconds, plug it back in.
2. Try the Mac's other USB-C port.
3. Restart the Mac with the controller unplugged, then plug it in after login.

### Still `!registered` after re-plugging into the other port

The device moved to `MPK Mini Mk II@01100000`, the other USB-C port, and was still `!registered, !matched`. The port it sits on was healthy:

```
ioreg -p IOService -w0 -l -r -c AppleT8132USBXHCI -n "AppleT8132USBXHCI@01000000" | grep -E "\+-o|EnumerationState|port-statistics"
```

`port-statistics` showed `kPortStatEnumerationFailureCount=0`, `kPortStatOverCurrentCount=0` and `kPortStatAddressFailureCount=0`. So there were no power or setup errors. The device was read (its descriptors are in `UsbDeviceSignature`) and then held back.

**Leading explanation: macOS accessory security.** On Apple Silicon laptops, macOS can hold a new USB accessory unregistered until the user approves it in a pop-up ("Allow accessory to connect?"). If that pop-up was missed or declined, the device stays in exactly this state: detected, no errors, no driver.

This couldn't be confirmed from the terminal, because the setting isn't readable through `defaults`.

**Check and fix:**
1. Open **System Settings → Privacy & Security** and scroll to **Security**.
2. Find **Allow accessories to connect**. If it says **Ask for new accessories** or **Ask every time**, set it to **Automatically when unlocked**. You can change it back later.
3. Unplug the controller, wait 10 seconds, plug it back in with the Mac unlocked, and click **Allow** if asked.
4. Run `ioreg -p IOService -w0 | grep -i "mpk"` and look for `registered, matched`.

### Fixed: accessory security was blocking it

Rob changed **Allow accessories to connect** to **Automatically when unlocked**. With no re-plug needed, the controller was set up straight away:

```
ioreg -p IOService -w0 | grep -i "mpk"
+-o MPK Mini Mk II@01100000  <class IOUSBHostDevice, registered, matched, active, busy 0 (32 ms), retain 46>

devices=4  sources=1  external=0
```

The device count went from 3 to 4 and MIDI inputs from 0 to 1.

**Root cause, in full:**
1. The old cable or the hub stopped the controller reaching macOS at all. Fixed with a new cable, plugged in directly.
2. macOS accessory security then held the controller back without registering it. Fixed in **System Settings → Privacy & Security → Allow accessories to connect**.

Next: open the app, turn on MIDI in Settings, and confirm the device shows as Connected with the "Akai MPK Mini" profile.

---

## 2026-11-03: testing the first-visit MIDI pop-up through Chrome's debugger

The Chrome debugging port changes per run, and an old Chrome can leave a stale one listed first. List them all and pick the one that has the app page:

```
for P in $(ps -axo command | grep -o "remote-debugging-port=[0-9]*" | cut -d= -f2 | sort -u); do echo "== $P"; curl -s http://127.0.0.1:$P/json/list | python3 -c "import json,sys; [print(t['type'], t['url']) for t in json.load(sys.stdin)]"; done
```

Take a screenshot of the page into a PNG file:

```
dart run tool/ws_rpc.dart $PAGE '{"id":1,"method":"Page.captureScreenshot","params":{"format":"png"}}' | python3 -c "import json,sys,base64; open('shot.png','wb').write(base64.b64decode(json.load(sys.stdin)['result']['data']))"
```

Simulate a first visit by clearing the app's saved settings, then reloading:

```
dart run tool/ws_rpc.dart $PAGE '{"id":2,"method":"Runtime.evaluate","params":{"expression":"localStorage.clear(); \"cleared\"","returnByValue":true}}' '{"id":3,"method":"Page.reload","params":{}}'
```

Results: the first screenshot had no pop-up, because `yuvi.settings.midiEnabled` was already `"true"` from the day before, and the pop-up skips people who already use MIDI. After clearing and reloading, the pop-up appeared and `yuvi.onboarding.midiHintSeen` was `"true"`.

