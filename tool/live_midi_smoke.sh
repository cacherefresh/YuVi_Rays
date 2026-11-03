#!/usr/bin/env bash
# Runs tool/live_midi_smoke.js in the YuVi Rays page through Chrome's debugger.
#
# 1. flutter run -d chrome --target lib/web_main.dart --web-port 8090
# 2. tool/live_midi_smoke.sh            (optional: page URL substring, default localhost:8090)
#
# Prints each step with PASS/FAIL. Exit code 0 only if every step passed.
set -euo pipefail
cd "$(dirname "$0")/.."
MATCH="${1:-localhost:8090}"

PAGE=""
for P in $(ps -axo command | grep -o "remote-debugging-port=[0-9]*" | cut -d= -f2 | sort -u); do
  PAGE=$(curl -s --max-time 2 "http://127.0.0.1:$P/json/list" | python3 -c "
import json, sys
pages = [t['webSocketDebuggerUrl'] for t in json.load(sys.stdin) if t['type'] == 'page' and '$MATCH' in t['url']]
print(pages[0] if pages else '')" 2>/dev/null || true)
  [ -n "$PAGE" ] && break
done
[ -z "$PAGE" ] && { echo "No Chrome page matching '$MATCH' with a debugging port. Start the app with flutter run -d chrome."; exit 2; }

MSG=$(python3 -c "
import json
print(json.dumps({'id': 1, 'method': 'Runtime.evaluate', 'params': {
  'expression': open('tool/live_midi_smoke.js').read(), 'awaitPromise': True, 'returnByValue': True, 'userGesture': True}}))")

dart run tool/ws_rpc.dart "$PAGE" "$MSG" 2>/dev/null | python3 -c "
import json, sys
r = json.load(sys.stdin)
v = r.get('result', {}).get('result', {}).get('value')
if not isinstance(v, dict):
    print('Script error:', json.dumps(r)[:800]); sys.exit(1)
for s in v.get('steps', []):
    print(('PASS' if s['pass'] else 'FAIL'), '-', s['name'], ('  (' + s['detail'] + ')') if s.get('detail') else '')
if v.get('error'): print('ERROR:', v['error'])
print('RESULT:', 'PASS' if v.get('pass') else 'FAIL')
sys.exit(0 if v.get('pass') else 1)"
