#!/usr/bin/env bash
# Records real MIDI from a controller into a session file that
# test/midi_fake_runner_test.dart can replay.
#
# 1. flutter run -d chrome --target lib/web_main.dart --web-port 8090
#    (MIDI must be allowed for the page: turn it on once in Settings.)
# 2. tool/capture_midi_session.sh 20 test/fixtures/mpk_mini_mk2/session_real.yaml
# 3. Press pads and turn knobs during the 20 seconds.
#
# Output: YAML with `t` (ms from the first message) and raw `bytes` per event.
set -euo pipefail
cd "$(dirname "$0")/.."
SECONDS_TO_RECORD="${1:-15}"
OUT="${2:-midi_session.yaml}"

PAGE=""
for P in $(ps -axo command | grep -o "remote-debugging-port=[0-9]*" | cut -d= -f2 | sort -u); do
  PAGE=$(curl -s --max-time 2 "http://127.0.0.1:$P/json/list" | python3 -c "
import json, sys
p = [t['webSocketDebuggerUrl'] for t in json.load(sys.stdin) if t['type'] == 'page' and 'localhost:8090' in t['url']]
print(p[0] if p else '')" 2>/dev/null || true)
  [ -n "$PAGE" ] && break
done
[ -z "$PAGE" ] && { echo "App page not found. Start it with flutter run -d chrome --web-port 8090."; exit 2; }

JS="navigator.requestMIDIAccess().then(async a => {
  const ev = []; const ins = [...a.inputs.values()];
  if (!ins.length) return {error: 'no MIDI input connected'};
  await Promise.all(ins.map(i => { i.onmidimessage = e => ev.push({ms: e.timeStamp, dev: i.name, bytes: Array.from(e.data)}); return i.open(); }));
  await new Promise(r => setTimeout(r, ${SECONDS_TO_RECORD} * 1000));
  ins.forEach(i => i.onmidimessage = null);
  return {device: ins[0].name, events: ev};
})"
MSG=$(JS="$JS" python3 -c "import json, os; print(json.dumps({'id': 1, 'method': 'Runtime.evaluate', 'params': {'expression': os.environ['JS'], 'awaitPromise': True, 'returnByValue': True}}))")

echo "Recording for ${SECONDS_TO_RECORD} s: press pads and turn knobs now..."
dart run tool/ws_rpc.dart "$PAGE" "$MSG" 2>/dev/null | OUT="$OUT" python3 -c "
import json, os, sys
v = json.load(sys.stdin).get('result', {}).get('result', {}).get('value') or {}
if 'error' in v or 'events' not in v:
    print('Capture failed:', v.get('error', 'no result (did the request time out?)')); sys.exit(1)
ev = [e for e in v['events'] if e['bytes'] and e['bytes'][0] != 0xF8]  # drop MIDI clock
t0 = ev[0]['ms'] if ev else 0
with open(os.environ['OUT'], 'w') as f:
    f.write('# Captured with tool/capture_midi_session.sh\n')
    f.write('device: %s\nsource: captured\nevents:\n' % v['device'])
    for e in ev:
        f.write('  - { t: %d, bytes: %s }\n' % (round(e['ms'] - t0), json.dumps(e['bytes'])))
print('Wrote %d events to %s' % (len(ev), os.environ['OUT']))"
