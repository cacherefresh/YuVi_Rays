// `dart:js_interop`/`package:web` (used by the real implementation) only
// compile for web targets. On native (macOS/Windows) builds, fall back to
// a stub so the rest of DeckWidget still compiles.
export 'blob_url_stub.dart' if (dart.library.js_interop) 'blob_url_web.dart';
