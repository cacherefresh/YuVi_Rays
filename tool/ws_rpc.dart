// Sends JSON commands to a debugger WebSocket and prints each reply.
//
// Works with both debuggers YuVi Rays exposes when run with `flutter run -d chrome`:
//   - Chrome DevTools Protocol (CDP): ws://127.0.0.1:<chrome-port>/devtools/page/<id>
//   - Dart VM Service (DWDS):         ws://127.0.0.1:<port>/<token>=/ws
//
// Usage:
//   dart run tool/ws_rpc.dart <ws-url> '<json message>' ['<json message>' ...]
//
// Each message needs an "id". The script waits for the reply with that id
// (up to 60 s) before sending the next one. Events without an id are ignored.
// See _DEVELOPER_NOTES/_NON_HUMAN_NOTES/debugging_local_server_and_midi.md
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln("usage: dart run tool/ws_rpc.dart <ws-url> '<json>' ...");
    exit(64);
  }
  final ws = await WebSocket.connect(args.first);
  final pending = <Object, Completer<Map<String, dynamic>>>{};
  ws.listen((frame) {
    final msg = jsonDecode(frame as String) as Map<String, dynamic>;
    pending.remove(msg['id'])?.complete(msg);
  });
  for (final raw in args.skip(1)) {
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    final done = Completer<Map<String, dynamic>>();
    pending[msg['id'] as Object] = done;
    ws.add(raw);
    final reply = await done.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => {'id': msg['id'], 'error': 'timeout'},
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(reply));
  }
  await ws.close();
}
